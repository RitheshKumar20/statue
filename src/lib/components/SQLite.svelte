<script lang="ts">
  import { onMount } from 'svelte';
  import sqlite3InitModule from '@dao-xyz/sqlite3-vec/wasm';

  export let dbPath: string; // e.g. '/demo.db'
  export let query: string; // e.g. 'SELECT * FROM users'

  let columns: string[] = [];
  let rows: any[][] = [];
  let loading = true;
  let error: string | null = null;

  const SQLITE_DESERIALIZE_FREEONCLOSE = 1;

  onMount(async () => {
    let db: any = null;
    let stmt: any = null;
    try {
      const sqlite3 = await sqlite3InitModule({
        print: () => {},
        printErr: console.error
      });

      const res = await fetch(dbPath);
      const buffer = await res.arrayBuffer();
      const bytes = new Uint8Array(buffer);
      const n = bytes.byteLength;

      db = new sqlite3.oo1.DB(':memory:');
      const ptr = sqlite3.wasm.allocFromTypedArray(bytes);
      const rc = sqlite3.capi.sqlite3_deserialize(
        db.pointer,
        'main',
        ptr,
        n,
        n,
        SQLITE_DESERIALIZE_FREEONCLOSE
      );
      if (rc) {
        throw new Error(
          sqlite3.capi.sqlite3_js_rc_str?.(rc) ?? `SQLite error ${rc}`
        );
      }

      stmt = db.prepare(query);
      columns = stmt.getColumnNames([]);
      while (stmt.step()) {
        rows.push(stmt.get([]));
      }
    } catch (e) {
      error = 'Failed to load database';
      console.error(e);
    } finally {
      try {
        if (stmt?.finalize) stmt.finalize();
      } catch (_) {}
      try {
        if (db?.close) db.close();
      } catch (_) {}
      loading = false;
    }
  });
</script>

{#if loading}
  <p>Loading data…</p>
{:else if error}
  <p>{error}</p>
{:else}
  <slot {columns} {rows} />
{/if}
