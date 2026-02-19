#!/bin/bash

# Test local statue-ssg package in a fresh project
# Usage: ./scripts/test-local.sh [template-name]

set -e

TEMPLATE="${1:-default}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_ROOT/build/test-$TEMPLATE"
TARBALL_NAME="statue-ssg-local.tgz"

echo "🗿 Testing local statue-ssg package (template: $TEMPLATE)..."

# 1. Create tarball from current project
echo "📦 Creating tarball..."
cd "$PROJECT_ROOT"
npm pack --pack-destination "$PROJECT_ROOT"
TARBALL=$(ls -t statue-ssg-*.tgz | head -1)
mv "$TARBALL" "$TARBALL_NAME"
echo "✓ Created $TARBALL_NAME"

# 2. Remove old test directory if exists
if [ -d "$TEST_DIR" ]; then
  echo "🗑️  Removing old test-preview directory..."
  rm -rf "$TEST_DIR"
fi

# 3. Create fresh test directory
echo "📁 Creating test-preview directory..."
mkdir -p "$TEST_DIR"

# 4. Move tarball to test directory
mv "$TARBALL_NAME" "$TEST_DIR/"

# 5. Setup new SvelteKit project and install local package
echo "🚀 Setting up new SvelteKit project..."
cd "$TEST_DIR"
yes | npx sv create . --template minimal --types ts --no-add-ons --install npm

echo "📥 Installing local statue-ssg..."
npm install "./$TARBALL_NAME"

echo "⚙️  Running statue init --template $TEMPLATE..."
npx statue init --template "$TEMPLATE"

echo "📥 Installing dependencies..."
npm install

# 6. Add demo routes from repo (so test-default includes demo-vector-search, demo-table)
if [ "$TEMPLATE" = "default" ]; then
  echo "📂 Copying demo routes into test project..."
  for demo in demo-vector-search demo-table; do
    src="$PROJECT_ROOT/src/routes/$demo"
    dst="$TEST_DIR/src/routes/$demo"
    if [ -d "$src" ]; then
      mkdir -p "$(dirname "$dst")"
      cp -R "$src" "$dst"
      echo "   ✓ $demo"
    fi
  done
  if [ -f "$PROJECT_ROOT/static/demo.db" ]; then
    cp "$PROJECT_ROOT/static/demo.db" "$TEST_DIR/static/demo.db"
    echo "   ✓ static/demo.db"
  fi
  # Ensure demo routes are prerendered (match literal ... spread, not any three chars)
  if [ -f "$TEST_DIR/svelte.config.js" ]; then
    sed -i.bak 's/\.\.\.tagRoutes/...tagRoutes, '\''\/demo-vector-search'\'', '\''\/demo-table'\''/' "$TEST_DIR/svelte.config.js" && rm -f "$TEST_DIR/svelte.config.js.bak"
  fi
fi

# 7. Clean up tarball
echo "🗑️  Cleaning up tarball..."
rm -f "$TARBALL_NAME"

echo ""
echo "✨ Setup complete!"
echo "📍 Test project location: $TEST_DIR"
echo ""
echo "🏃 Starting dev server..."
npm run build && npm run preview
exec $SHELL