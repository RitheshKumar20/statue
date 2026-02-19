# SQLite Wasm + sqlite-vec

This directory holds the SQLite Wasm build with [sqlite-vec](https://github.com/asg017/sqlite-vec) (vector search) compiled in.

## Files

- `sqlite3.mjs` – ESM init module
- `sqlite3.wasm` – WebAssembly binary

## Building (required before using SQLite/vector components)

**Linux:** From repo root, run:

```bash
npm run build:wasm
```

This script will install [Emscripten](https://emscripten.org/) (emsdk) into `.emsdk` if `emcc` is not in your PATH. You need `python3` (or `python`) and `git` installed. The first run can take 10–20 minutes (downloads emsdk and SQLite source, then builds).

**Other systems:** Install Emscripten yourself and add `emcc` to PATH, then run `npm run build:wasm`.

Optional: use a local clone of sqlite-vec to avoid cloning each time:

```bash
SQLITE_VEC_DIR=/path/to/sqlite-vec npm run build:wasm
```

After building, commit `sqlite-wasm/sqlite3.mjs` and `sqlite-wasm/sqlite3.wasm` so others and CI do not need to build.
