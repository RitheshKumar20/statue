#!/usr/bin/env bash
# Build SQLite Wasm with sqlite-vec from asg017/sqlite-vec.
# On Linux, installs build dependencies (tcl, python3, make, etc.) and Emscripten (emsdk) if needed.
# Output: sqlite-wasm/sqlite3.mjs, sqlite-wasm/sqlite3.wasm
# Run from repo root: bash scripts/build-sqlite-vec-wasm.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/sqlite-wasm"
EMSDK_DIR="$REPO_ROOT/.emsdk"

# Packages required for SQLite/sqlite-vec build and emsdk:
#   tcl (tclsh), python3, make, curl, unzip, git, gcc, libsqlite3-dev (sqlite3.h), gettext (envsubst for sqlite-vec.h)
install_linux_deps() {
  if ! command -v apt-get &>/dev/null; then
    echo "error: this script requires apt-get (Debian/Ubuntu)."
    exit 1
  fi
  local need_install=
  command -v tclsh &>/dev/null    || need_install=1
  command -v make &>/dev/null    || need_install=1
  command -v python3 &>/dev/null || need_install=1
  command -v curl &>/dev/null    || need_install=1
  command -v unzip &>/dev/null   || need_install=1
  command -v git &>/dev/null     || need_install=1
  command -v envsubst &>/dev/null || need_install=1
  dpkg -l libsqlite3-dev &>/dev/null || need_install=1
  [[ -n "$need_install" ]] || return 0

  echo "Installing build dependencies (tcl, python3, make, curl, unzip, git, gcc, libsqlite3-dev, gettext)..."
  sudo apt-get update
  sudo apt-get install -y tcl python3 make curl unzip git build-essential libsqlite3-dev gettext
  if ! command -v tclsh &>/dev/null; then
    echo "error: tclsh still not found after install. SQLite build requires tcl 8.4+."
    exit 1
  fi
  if ! [[ -f /usr/include/sqlite3.h ]]; then
    echo "error: sqlite3.h still not findable after install. Install libsqlite3-dev."
    exit 1
  fi
  echo "Build dependencies ready."
}

ensure_emcc() {
  if command -v emcc &>/dev/null; then
    return 0
  fi
  case "$(uname -s)" in
    Linux)
      install_linux_deps
      echo "emcc not found. Installing Emscripten (emsdk) into $EMSDK_DIR ..."
      if ! command -v python3 &>/dev/null; then
        echo "error: python3 not found after installing dependencies."
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

case "$(uname -s)" in
  Linux) install_linux_deps ;;
esac
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
# Makefile uses -I./ -Ivendor; emcc doesn't see /usr/include. Copy system headers so wasm.c finds sqlite3.h.
if [[ -f /usr/include/sqlite3.h ]]; then
  cp -f /usr/include/sqlite3.h /usr/include/sqlite3ext.h ./ 2>/dev/null || cp -f /usr/include/sqlite3.h ./
fi
# Generate sqlite-vec.h from sqlite-vec.h.tmpl (required for wasm.c; wasm target doesn't depend on it in Makefile).
make sqlite-vec.h
# If we installed emsdk in this shell, emcc is in PATH from source ./emsdk_env.sh
make wasm

cp -f dist/.wasm/sqlite3.mjs "$OUT_DIR/"
cp -f dist/.wasm/sqlite3.wasm "$OUT_DIR/"
echo "Done. Output: $OUT_DIR/sqlite3.mjs, $OUT_DIR/sqlite3.wasm"
