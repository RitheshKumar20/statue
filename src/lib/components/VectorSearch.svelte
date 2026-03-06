<script lang="ts">
  import { onMount } from 'svelte';
  import sqlite3InitModule from '@dao-xyz/sqlite3-vec/wasm';
  import { embed } from '$lib/deterministic-embedder.js';

  export let dbPath = '/demo.db';
  export let limit = 5;
  export let tableName = 'users';
  export let vecTableName = 'user_vecs';

  const SQLITE_DESERIALIZE_FREEONCLOSE = 1;
  const DIMENSION = 8;

  let db: any = null;
  let sqlite3: any = null;
  let loading = true;
  let error: string | null = null;
  let queryText = '';
  let searching = false;
  let searched = false;
  let results: Array<{ id: number; name: string; role: string; content: string; distance: number }> = [];

  onMount(async () => {
    try {
      sqlite3 = await sqlite3InitModule({
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
    } catch (e) {
      error = 'Failed to load database';
      console.error(e);
    } finally {
      loading = false;
    }
  });

  function handleSearch() {
    if (!db || !queryText.trim()) return;
    searching = true;
    searched = true;
    results = [];
    try {
      const queryVec = embed(queryText.trim(), DIMENSION);
      const q = db.prepare(
        `SELECT rowid, vec_distance_l2(vector, ?1) AS d FROM ${vecTableName} ORDER BY d LIMIT ${limit}`
      );
      q.bind({ 1: queryVec.buffer });
      const rows: Array<{ rowid: number; d: number }> = [];
      while (q.step()) {
        const row = q.get({});
        rows.push({ rowid: row?.rowid ?? row?.[0], d: row?.d ?? row?.[1] });
      }
      q.finalize();

      const getUser = db.prepare(
        `SELECT id, name, role, content FROM ${tableName} WHERE id = ? LIMIT 1`
      );
      for (const { rowid, d } of rows) {
        getUser.bind([rowid]);
        if (getUser.step()) {
          const r = getUser.get({});
          results = [
            ...results,
            {
              id: r?.id ?? r?.[0],
              name: r?.name ?? r?.[1] ?? '',
              role: r?.role ?? r?.[2] ?? '',
              content: r?.content ?? r?.[3] ?? '',
              distance: d
            }
          ];
        }
        getUser.reset();
      }
      getUser.finalize();
    } catch (e) {
      console.error(e);
      error = 'Search failed';
    } finally {
      searching = false;
    }
  }
</script>

{#if loading}
  <p>Loading database…</p>
{:else if error}
  <p class="error">{error}</p>
{:else}
  <div class="vector-search">
    <div class="search-bar">
      <input
        type="text"
        bind:value={queryText}
        placeholder="Search by meaning…"
        on:keydown={(e) => e.key === 'Enter' && handleSearch()}
      />
      <button on:click={handleSearch} disabled={searching}>
        {searching ? 'Searching…' : 'Search'}
      </button>
    </div>
    {#if results.length > 0}
      <ul class="results">
        {#each results as r}
          <li>
            <strong>{r.name}</strong> ({r.role}) — {r.content}
            <span class="distance">L2 distance: {r.distance.toFixed(4)}</span>
          </li>
        {/each}
      </ul>
    {:else if searched && results.length === 0 && !searching}
      <p class="hint">No results found.</p>
    {:else if !searched}
      <p class="hint">Enter a query and click Search.</p>
    {/if}
  </div>
{/if}

<style>
  .vector-search {
    margin: 1.5rem 0;
  }
  .search-bar {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }
  .search-bar input {
    flex: 1;
    padding: 0.5rem;
  }
  .search-bar button {
    padding: 0.5rem 1rem;
  }
  .results {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  .results li {
    padding: 0.75rem;
    margin-bottom: 0.5rem;
    background: var(--theme-bg-secondary, #f5f5f5);
    border-radius: 4px;
  }
  .distance {
    display: block;
    font-size: 0.85em;
    color: var(--theme-text-muted, #666);
    margin-top: 0.25rem;
  }
  .error {
    color: var(--theme-error, #c00);
  }
  .hint {
    color: var(--theme-text-muted, #666);
    font-size: 0.9em;
  }
</style>
