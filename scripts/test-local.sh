#!/bin/bash

set -e

TEMPLATE="${1:-default}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_ROOT/build/test-$TEMPLATE"
TARBALL_NAME="statue-ssg-local.tgz"

cd "$PROJECT_ROOT"
npm pack --pack-destination "$PROJECT_ROOT"
TARBALL=$(ls -t statue-ssg-*.tgz | head -1)
mv "$TARBALL" "$TARBALL_NAME"

if [ -d "$TEST_DIR" ]; then
  rm -rf "$TEST_DIR"
fi
mkdir -p "$TEST_DIR"

mv "$TARBALL_NAME" "$TEST_DIR/"

cd "$TEST_DIR"
yes | npx sv create . --template minimal --types ts --no-add-ons --install npm
npm install "./$TARBALL_NAME"

npx statue init --template "$TEMPLATE"

# Copy demo-table route from project src
if [ -d "$PROJECT_ROOT/src/routes/demo-table" ]; then
  mkdir -p "$TEST_DIR/src/routes/demo-table"
  cp -r "$PROJECT_ROOT/src/routes/demo-table/"* "$TEST_DIR/src/routes/demo-table/"
fi

# Copy embedder for demo-table (vector search)
if [ -f "$PROJECT_ROOT/src/lib/deterministic-embedder.js" ]; then
  mkdir -p "$TEST_DIR/src/lib"
  cp "$PROJECT_ROOT/src/lib/deterministic-embedder.js" "$TEST_DIR/src/lib/deterministic-embedder.js"
fi

# Create demo.db (users + content), add vec0 when native extension is available, then copy for demo-table
if [ -f "$PROJECT_ROOT/scripts/create-demo-db.sh" ]; then
  mkdir -p "$PROJECT_ROOT/static"
  (cd "$PROJECT_ROOT" && bash scripts/create-demo-db.sh)
  (cd "$PROJECT_ROOT" && node scripts/add-vec0-to-demo-db.mjs) || true
  mkdir -p "$TEST_DIR/static"
  cp "$PROJECT_ROOT/static/demo.db" "$TEST_DIR/static/demo.db"
fi

cd "$TEST_DIR"

npm install
npm run build