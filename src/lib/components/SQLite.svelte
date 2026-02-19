<script lang="ts">
  import { onMount } from 'svelte';
  import wasmUrl from '../../../sqlite-wasm/sqlite3.wasm?url';

  export let dbPath: string; // e.g. '/demo.db'
  export let query: string; // e.g. 'SELECT * FROM users'

  let columns: string[] = [];
  let rows: any[][] = [];
  let loading = true;
  let error: string | null = null;

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

      const db = new sqlite3.oo1.DB(':memory:');
      const capi = sqlite3.capi;
      const wasm = sqlite3.wasm;

      const ptr = wasm.alloc(n);
      wasm.heap8u().set(bytes, ptr);
      const rc = capi.sqlite3_deserialize(
        db.pointer,
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

      const columnNames: string[] = [];
      const resultRows: any[][] = [];
      db.exec({
        sql: query,
        columnNames,
        resultRows,
        rowMode: 'array',
        returnValue: 'this'
      });

      columns = columnNames;
      rows = resultRows;
      db.close();
    } catch (e) {
      error = 'Failed to load database';
      console.error(e);
    } finally {
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
