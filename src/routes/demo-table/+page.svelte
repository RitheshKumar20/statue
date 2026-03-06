<script lang="ts">
  import { Table, SQLite, VectorSearch } from 'statue-ssg';
</script>

<h1>Table Demo (SQLite-backed)</h1>

<section class="vector-search-section">
  <h2>Vector search</h2>
  <VectorSearch dbPath="/demo.db" limit={5} />
</section>

<div class="table-wrapper">
  <SQLite dbPath="/demo.db" query="SELECT * FROM users" let:columns let:rows>
    <Table {columns} {rows} />
  </SQLite>
</div>

<style>
  .vector-search-section {
    max-width: 900px;
    margin: 2rem auto;
    padding: 0 1rem;
  }
  .vector-search-section h2 {
    font-size: 1.25rem;
    margin-bottom: 0.5rem;
  }
  .table-wrapper {
    max-width: 900px;
    margin: 2rem auto;
    padding: 1rem;
  }
</style>