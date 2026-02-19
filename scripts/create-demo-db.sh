#!/usr/bin/env bash
# Create static/demo.db with users, vec0 (user_vec), and query_vectors using the
# native sqlite-vec CLI from the same repo used for the WASM build. No Python.
# Requires: same deps as build-sqlite-vec-wasm.sh (tcl, make, envsubst, etc.) and Node.
# Optional: set SQLITE_VEC_DIR to an existing sqlite-vec clone to avoid re-cloning.
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DB_PATH="${1:-static/demo.db}"
rm -f "$DB_PATH"
mkdir -p "$(dirname "$DB_PATH")"

if [[ -n "${SQLITE_VEC_DIR:-}" ]]; then
  SQLITE_VEC_REPO="$SQLITE_VEC_DIR"
else
  TMP_DIR=$(mktemp -d)
  trap "rm -rf '$TMP_DIR'" EXIT
  echo "Cloning asg017/sqlite-vec..."
  git clone --depth 1 https://github.com/asg017/sqlite-vec.git "$TMP_DIR/sqlite-vec"
  SQLITE_VEC_REPO="$TMP_DIR/sqlite-vec"
fi

echo "Building native sqlite-vec CLI..."
cd "$SQLITE_VEC_REPO"

# vendor/ is gitignored; CLI target needs vendor/sqlite3.c and vendor/shell.c from SQLite
if [[ ! -f vendor/sqlite3.c || ! -f vendor/shell.c ]]; then
  SQLITE_VERSION=3450300
  SQLITE_YEAR=2024
  echo "Fetching SQLite amalgamation and source for vendor/..."
  mkdir -p vendor
  BUILD_DIR="$SQLITE_VEC_REPO/dist/.build"
  mkdir -p "$BUILD_DIR"

  # Amalgamation has prebuilt sqlite3.c and sqlite3.h (no configure/make)
  AMAL_ZIP="$BUILD_DIR/sqlite-amalgamation-$SQLITE_VERSION.zip"
  curl -sSfL -o "$AMAL_ZIP" "https://www.sqlite.org/$SQLITE_YEAR/sqlite-amalgamation-$SQLITE_VERSION.zip"
  unzip -q -o "$AMAL_ZIP" -d "$BUILD_DIR"
  AMAL_DIR=$(find "$BUILD_DIR" -maxdepth 2 -name sqlite3.c -type f 2>/dev/null | head -1)
  AMAL_DIR=$(dirname "$AMAL_DIR")
  if [[ -z "$AMAL_DIR" || ! -f "$AMAL_DIR/sqlite3.h" ]]; then
    echo "error: could not find sqlite3.c/sqlite3.h in amalgamation zip"
    exit 1
  fi
  cp -f "$AMAL_DIR/sqlite3.c" "$AMAL_DIR/sqlite3.h" vendor/

  # shell.c comes from the full source zip (canonical tree)
  SRC_ZIP="$BUILD_DIR/sqlite-src-$SQLITE_VERSION.zip"
  curl -sSfL -o "$SRC_ZIP" "https://www.sqlite.org/$SQLITE_YEAR/sqlite-src-$SQLITE_VERSION.zip"
  unzip -q -o "$SRC_ZIP" -d "$BUILD_DIR"
  SHELL_C=$(find "$BUILD_DIR" -maxdepth 4 -name shell.c -type f 2>/dev/null | head -1)
  if [[ -z "$SHELL_C" || ! -f "$SHELL_C" ]]; then
    echo "error: could not find shell.c in source zip"
    exit 1
  fi
  cp -f "$SHELL_C" vendor/
fi

make sqlite-vec.h
# Linker needs -lm after .a files that use sqrt/ceil; upstream Makefile puts -ldl -lm before them
sed -i.bak '/-ldl -lm \\$/d' Makefile
sed -i.bak 's/sqlite-vec\.a -o/sqlite-vec.a -ldl -lm -o/' Makefile
make cli
cd "$REPO_ROOT"

if [[ ! -f "$SQLITE_VEC_REPO/dist/sqlite3" ]]; then
  echo "error: sqlite3 CLI not found at $SQLITE_VEC_REPO/dist/sqlite3"
  exit 1
fi

echo "Creating demo database..."
node scripts/create-demo-db-with-vectors.js | "$SQLITE_VEC_REPO/dist/sqlite3" "$DB_PATH"

echo "Demo database created at $DB_PATH"
