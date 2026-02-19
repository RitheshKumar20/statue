<script lang="ts">
  import { VectorSearch } from 'statue-ssg';
</script>

<h1>Vector search demo (sqlite-vec)</h1>
<p>Select a query to run KNN vector search over the demo DB. Results show matching users and distance.</p>

<div class="vector-search-wrapper">
  <VectorSearch dbPath="/demo.db" placeholder="Select a query…" limit={5} />
</div>

<style>
  .vector-search-wrapper {
    max-width: 560px;
    margin: 2rem auto;
    padding: 1rem;
  }
</style>
