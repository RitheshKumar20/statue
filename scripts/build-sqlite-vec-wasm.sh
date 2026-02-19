#!/usr/bin/env bash
# Build SQLite Wasm with sqlite-vec from asg017/sqlite-vec.
# On Linux, installs Emscripten (emsdk) automatically if emcc is not found.
# Requires: make, curl, unzip, git.
# Output: sqlite-wasm/sqlite3.mjs, sqlite-wasm/sqlite3.wasm
# Run from repo root: bash scripts/build-sqlite-vec-wasm.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/sqlite-wasm"
EMSDK_DIR="$REPO_ROOT/.emsdk"

ensure_emcc() {
  if command -v emcc &>/dev/null; then
    return 0
  fi
  case "$(uname -s)" in
    Linux)
      echo "emcc not found. Installing Emscripten (emsdk) into $EMSDK_DIR ..."
      if ! command -v python3 &>/dev/null; then
        sudo apt-get update && sudo apt-get install python3 -y
        exit 1
      fi
      if ! command -v python &>/dev/null; then
        export PATH="$REPO_ROOT/.local/bin:$PATH"
        mkdir -p "$REPO_ROOT/.local/bin"
        ln -sf "$(command -v python3)" "$REPO_ROOT/.local/bin/python" 2>/dev/null || true
        if ! command -v python &>/dev/null; then
          echo "error: emsdk requires 'python' in PATH. Install python or python3-is-python3 and try again."
          exit 1
        fi
      fi
      if [[ ! -d "$EMSDK_DIR" ]]; then
        git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
      fi
      cd "$EMSDK_DIR"
      ./emsdk install latest
      ./emsdk activate latest
      source ./emsdk_env.sh
      cd "$REPO_ROOT"
      if ! command -v emcc &>/dev/null; then
        echo "error: emcc still not in PATH after emsdk install."
        exit 1
      fi
      echo "Emscripten ready."
      ;;
    *)
      echo "error: emcc (Emscripten) not found. On Linux this script can install it automatically."
      echo "On other systems, install Emscripten and add it to PATH:"
      echo "  https://emscripten.org/docs/getting_started/downloads.html"
      exit 1
      ;;
  esac
}

ensure_emcc
mkdir -p "$OUT_DIR"

if [[ -n "${SQLITE_VEC_DIR:-}" ]]; then
  SQLITE_VEC_REPO="$SQLITE_VEC_DIR"
else
  TMP_DIR=$(mktemp -d)
  trap "rm -rf '$TMP_DIR'" EXIT
  echo "Cloning asg017/sqlite-vec..."
  git clone --depth 1 https://github.com/asg017/sqlite-vec.git "$TMP_DIR/sqlite-vec"
  SQLITE_VEC_REPO="$TMP_DIR/sqlite-vec"
fi

echo "Building WASM (this may take a few minutes)..."
cd "$SQLITE_VEC_REPO"
# If we installed emsdk in this shell, emcc is in PATH from source ./emsdk_env.sh
make wasm

cp -f dist/.wasm/sqlite3.mjs "$OUT_DIR/"
cp -f dist/.wasm/sqlite3.wasm "$OUT_DIR/"
echo "Done. Output: $OUT_DIR/sqlite3.mjs, $OUT_DIR/sqlite3.wasm"
