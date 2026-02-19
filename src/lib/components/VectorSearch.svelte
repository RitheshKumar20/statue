<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import wasmUrl from '../../../sqlite-wasm/sqlite3.wasm?url';

  /** DB path, e.g. '/demo.db'. Must contain user_vec (vec0) and query_vectors table. */
  export let dbPath = '/demo.db';
  /** Placeholder for the query selector. */
  export let placeholder = 'Select a query…';
  /** Max number of results (k). */
  export let limit = 5;
  /** Vec0 table name (must match create-demo-db script). */
  export let vecTableName = 'user_vec';
  /** Query vectors table name (must match create-demo-db script). */
  export let queryVectorsTableName = 'query_vectors';

  let loading = true;
  let error: string | null = null;
  let queryNames: string[] = [];
  let selectedQuery: string | null = null;
  let results: { id: number; name: string; role: string; distance: number }[] = [];
  let db: { close: () => void; exec: (opts: unknown) => void; prepare: (sql: string) => unknown } | null = null;

  onMount(async () => {
    try {
      const initModule = (await import('../../../sqlite-wasm/sqlite3.mjs')).default;
      const sqlite3 = await initModule({
        print: () => {},
        printErr: () => {},
        locateFile: (file: string) => (file.endsWith('.wasm') ? wasmUrl : file)
      });

      const res = await fetch(dbPath);
      const buffer = await res.arrayBuffer();
      const bytes = new Uint8Array(buffer);
      const n = bytes.length;

      const database = new sqlite3.oo1.DB(':memory:');
      const capi = sqlite3.capi;
      const wasm = sqlite3.wasm;

      const ptr = wasm.alloc(n);
      wasm.heap8u().set(bytes, ptr);
      const rc = capi.sqlite3_deserialize(
        database.pointer,
        'main',
        ptr,
        n,
        n,
        capi.SQLITE_DESERIALIZE_RESIZEABLE | capi.SQLITE_DESERIALIZE_FREEONCLOSE
      );
      if (rc !== capi.SQLITE_OK) {
        wasm.dealloc(ptr);
        throw new Error('sqlite3_deserialize failed');
      }

      // Confirm vec is available
      try {
        database.exec({ sql: 'SELECT vec_version();', returnValue: 'this' });
      } catch {
        throw new Error('vec extension not available');
      }

      const resultRows: unknown[] = [];
      database.exec({
        sql: `SELECT name FROM ${queryVectorsTableName} ORDER BY name`,
        rowMode: 'array',
        resultRows,
        returnValue: 'this'
      });
      queryNames = resultRows.map((row: unknown) => (row as string[])[0]);

      db = database;
      sqlite3Module = sqlite3;
    } catch (e) {
      error = 'Failed to load database';
      console.error(e);
    } finally {
      loading = false;
    }
  });

  onDestroy(() => {
    if (db) {
      db.close();
      db = null;
    }
  });

  function runSearch(name: string) {
    selectedQuery = name;
    results = [];
    if (!db) return;

    try {
      const getQuery = db.prepare(
        `SELECT embedding FROM ${queryVectorsTableName} WHERE name = ?`
      ) as { bind: (i: number, v: string) => void; step: () => boolean; getBlob: (col: number) => Uint8Array; finalize: () => void };
      getQuery.bind(1, name);
      if (!getQuery.step()) {
        getQuery.finalize();
        return;
      }
      const embedding = getQuery.getBlob(0);
      getQuery.finalize();

      if (!embedding?.buffer) return;
      const queryBlob = embedding.buffer;

      const stmt = db.prepare(
        `SELECT rowid, distance FROM ${vecTableName} WHERE embedding MATCH ? ORDER BY distance LIMIT ?`
      ) as { bind: (i: number, v: ArrayBuffer | number) => void; bindAsBlob?: (i: number, v: ArrayBuffer | Uint8Array) => void; step: () => boolean; get: (col: number) => number; finalize: () => void };
      if (stmt.bindAsBlob) {
        stmt.bindAsBlob(1, queryBlob);
      } else {
        stmt.bind(1, queryBlob);
      }
      stmt.bind(2, limit);
      const matchRows: { rowid: number; distance: number }[] = [];
      while (stmt.step()) {
        matchRows.push({ rowid: stmt.get(0), distance: stmt.get(1) });
      }
      stmt.finalize();

      if (matchRows.length === 0) {
        results = [];
        return;
      }

      const idToUser: Record<number, { id: number; name: string; role: string }> = {};
      const execOpts = {
        sql: 'SELECT id, name, role FROM users',
        rowMode: 'array' as const,
        resultRows: [] as unknown[],
        returnValue: 'this' as const
      };
      db.exec(execOpts);
      const allRows = execOpts.resultRows as [number, string, string][];
      for (const r of allRows) {
        idToUser[r[0]] = { id: r[0], name: r[1], role: r[2] };
      }

      results = matchRows
        .map(({ rowid, distance }) => {
          const u = idToUser[rowid];
          return u ? { ...u, distance } : null;
        })
        .filter(Boolean) as { id: number; name: string; role: string; distance: number }[];
    } catch (e) {
      console.error(e);
      results = [];
    }
  }
</script>

{#if loading}
  <p>Loading…</p>
{:else if error}
  <p>{error}</p>
{:else}
  <div class="vector-search">
    <label for="vector-query-select">{placeholder}</label>
    <select
      id="vector-query-select"
      value={selectedQuery ?? ''}
      on:change={(e) => {
        const target = e.currentTarget;
        const v = target?.value ?? '';
        selectedQuery = v || null;
        if (v) runSearch(v);
      }}
    >
      <option value="">—</option>
      {#each queryNames as name}
        <option value={name}>{name}</option>
      {/each}
    </select>

    {#if selectedQuery}
      {#if results.length === 0}
        <p class="no-results">No results.</p>
      {:else}
        <ul class="results">
          {#each results as r}
            <li>{r.name} — {r.role} (distance: {r.distance.toFixed(4)})</li>
          {/each}
        </ul>
      {/if}
    {/if}
  </div>
#endif}

<style>
  .vector-search {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    max-width: 480px;
  }
  .vector-search select {
    padding: 0.25rem 0.5rem;
  }
  .results {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  .results li {
    padding: 0.25rem 0;
    border-bottom: 1px solid var(--theme-border, #eee);
  }
  .no-results {
    color: var(--theme-muted, #666);
  }
</style>
