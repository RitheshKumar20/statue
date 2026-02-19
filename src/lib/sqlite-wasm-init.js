/**
 * Singleton init for SQLite WASM. The Emscripten module must only be initialized once
 * per page (second init triggers "Module.postRun already been processed").
 * Uses a global promise (set before any await) and caches the resolved instance so
 * all chunks share one init; async guard skips initModule() if we lost the race.
 */

const WASM_BASE = '/sqlite-wasm';

const GLOBAL_PROMISE_KEY = '__statue_sqlite3_init_promise__';
const GLOBAL_INSTANCE_KEY = '__statue_sqlite3_instance__';

/**
 * @param {{ print?: (s: string) => void; printErr?: (s: string) => void; locateFile?: (file: string) => string }} [opts]
 * @returns {Promise<object>} Resolved SQLite WASM API (oo1, capi, wasm, etc.)
 */
export function getSqlite3(opts = {}) {
  if (globalThis[GLOBAL_INSTANCE_KEY]) {
    return Promise.resolve(globalThis[GLOBAL_INSTANCE_KEY]);
  }
  if (!globalThis[GLOBAL_PROMISE_KEY]) {
    let resolveInit;
    let rejectInit;
    const promise = new Promise((resolve, reject) => {
      resolveInit = resolve;
      rejectInit = reject;
    });
    globalThis[GLOBAL_PROMISE_KEY] = promise;
    const ourPromise = promise;
    (async () => {
      try {
        if (globalThis[GLOBAL_PROMISE_KEY] !== ourPromise) {
          const other = await globalThis[GLOBAL_PROMISE_KEY];
          resolveInit(other);
          return;
        }
        const initModule = (await import(/* @viteIgnore */ `${WASM_BASE}/sqlite3.mjs`)).default;
        if (globalThis[GLOBAL_INSTANCE_KEY]) {
          resolveInit(globalThis[GLOBAL_INSTANCE_KEY]);
          return;
        }
        const sqlite3 = await initModule({
          print: opts.print ?? (() => {}),
          printErr: opts.printErr ?? (() => {}),
          locateFile: opts.locateFile ?? ((file) => (file.endsWith('.wasm') ? `${WASM_BASE}/sqlite3.wasm` : file))
        });
        globalThis[GLOBAL_INSTANCE_KEY] = sqlite3;
        resolveInit(sqlite3);
      } catch (e) {
        delete globalThis[GLOBAL_PROMISE_KEY];
        rejectInit(e);
      }
    })();
  }
  return globalThis[GLOBAL_PROMISE_KEY];
}

export { WASM_BASE };
