<script lang="ts">
  let {
    filters,
    namespaces,
    onChange,
  }: {
    filters: {
      missing: boolean;
      locked: boolean;
      stale: boolean;
      namespace: string | null;
      search: string;
    };
    namespaces: string[];
    onChange: (next: typeof filters) => void;
  } = $props();

  function patch(p: Partial<typeof filters>) {
    onChange({ ...filters, ...p });
  }
</script>

<aside class="panel">
  <div class="group">
    <label class="search">
      <span>Search</span>
      <input
        type="search"
        placeholder="key or string…"
        value={filters.search}
        oninput={(e) => patch({ search: (e.currentTarget as HTMLInputElement).value })}
      />
    </label>
  </div>

  <div class="group">
    <h3>Show only</h3>
    <label>
      <input
        type="checkbox"
        checked={filters.missing}
        onchange={(e) => patch({ missing: (e.currentTarget as HTMLInputElement).checked })}
      />
      Missing
    </label>
    <label>
      <input
        type="checkbox"
        checked={filters.locked}
        onchange={(e) => patch({ locked: (e.currentTarget as HTMLInputElement).checked })}
      />
      Locked
    </label>
    <label>
      <input
        type="checkbox"
        checked={filters.stale}
        onchange={(e) => patch({ stale: (e.currentTarget as HTMLInputElement).checked })}
      />
      Stale
    </label>
  </div>

  {#if namespaces.length > 0}
    <div class="group">
      <h3>Namespace</h3>
      <label>
        <input
          type="radio"
          name="namespace"
          checked={filters.namespace === null}
          onchange={() => patch({ namespace: null })}
        />
        (all)
      </label>
      {#each namespaces as ns}
        <label>
          <input
            type="radio"
            name="namespace"
            checked={filters.namespace === ns}
            onchange={() => patch({ namespace: ns })}
          />
          {ns}
        </label>
      {/each}
    </div>
  {/if}
</aside>

<style>
  .panel {
    width: 220px;
    flex: 0 0 220px;
    padding: 16px;
    border-right: 1px solid var(--border);
    background: var(--bg-elev);
    overflow-y: auto;
  }
  .group {
    margin-bottom: 24px;
  }
  .group h3 {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--fg-muted);
    font-weight: 600;
    margin: 0 0 8px 0;
  }
  .group label {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 0;
    cursor: pointer;
  }
  .search span {
    display: block;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--fg-muted);
    font-weight: 600;
    margin-bottom: 6px;
  }
  .search input {
    width: 100%;
    padding: 6px 8px;
    border: 1px solid var(--border);
    border-radius: 4px;
    background: var(--bg);
  }
  .search input:focus {
    outline: none;
    border-color: var(--accent);
  }
</style>
