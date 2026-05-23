<script lang="ts">
  import type { StatusRow } from './api';

  let {
    filters,
    namespaces,
    locales,
    statusByLocale,
    activeLocale,
    onChange,
    onLocaleChange,
  }: {
    filters: {
      missing: boolean;
      locked: boolean;
      stale: boolean;
      namespace: string | null;
      search: string;
    };
    namespaces: string[];
    locales: string[];
    statusByLocale: Record<string, StatusRow>;
    activeLocale: string | null;
    onChange: (next: typeof filters) => void;
    onLocaleChange: (locale: string) => void;
  } = $props();

  function patch(p: Partial<typeof filters>) {
    onChange({ ...filters, ...p });
  }

  function pct(v: number): string {
    if (v === 1) return '100%';
    return `${Math.round(v * 100)}%`;
  }

  function clearFilters() {
    onChange({
      missing: false,
      locked: false,
      stale: false,
      namespace: null,
      search: '',
    });
  }

  let hasActiveFilter = $derived(
    filters.missing ||
    filters.locked ||
    filters.stale ||
    filters.namespace !== null ||
    filters.search.length > 0,
  );
</script>

<aside class="panel">
  <div class="group">
    <h3>Languages</h3>
    <ul class="locales">
      {#each locales as locale}
        {@const row = statusByLocale[locale]}
        <li>
          <button
            type="button"
            class="locale"
            class:active={locale === activeLocale}
            onclick={() => onLocaleChange(locale)}
          >
            <span class="code">{locale}</span>
            {#if row}
              <span class="coverage" title={`${row.missing} missing · ${row.stale} stale · ${row.locked} locked`}>
                {pct(row.coverage)}
              </span>
              <span class="bar">
                <span class="fill" style:width={`${Math.round(row.coverage * 100)}%`}></span>
              </span>
              <span class="counts">
                {#if row.missing > 0}
                  <span class="dot dot-missing" title={`${row.missing} missing`}>{row.missing}</span>
                {/if}
                {#if row.stale > 0}
                  <span class="dot dot-stale" title={`${row.stale} stale`}>{row.stale}</span>
                {/if}
              </span>
            {:else}
              <span class="coverage muted">—</span>
            {/if}
          </button>
        </li>
      {/each}
    </ul>
  </div>

  <div class="group">
    <h3>Search</h3>
    <div class="search">
      <input
        type="search"
        placeholder="Key or string…"
        value={filters.search}
        oninput={(e) => patch({ search: (e.currentTarget as HTMLInputElement).value })}
      />
    </div>
  </div>

  <div class="group">
    <div class="group-head">
      <h3>Filters</h3>
      {#if hasActiveFilter}
        <button type="button" class="clear" onclick={clearFilters}>Clear</button>
      {/if}
    </div>
    <label class="check">
      <input
        type="checkbox"
        checked={filters.missing}
        onchange={(e) => patch({ missing: (e.currentTarget as HTMLInputElement).checked })}
      />
      <span class="dot dot-missing"></span>
      Missing
    </label>
    <label class="check">
      <input
        type="checkbox"
        checked={filters.stale}
        onchange={(e) => patch({ stale: (e.currentTarget as HTMLInputElement).checked })}
      />
      <span class="dot dot-stale"></span>
      Stale
    </label>
    <label class="check">
      <input
        type="checkbox"
        checked={filters.locked}
        onchange={(e) => patch({ locked: (e.currentTarget as HTMLInputElement).checked })}
      />
      <span class="dot dot-locked"></span>
      Locked
    </label>
  </div>

  {#if namespaces.length > 0}
    <div class="group">
      <h3>Namespace</h3>
      <label class="check radio">
        <input
          type="radio"
          name="namespace"
          checked={filters.namespace === null}
          onchange={() => patch({ namespace: null })}
        />
        <span class="ns-all">All</span>
      </label>
      {#each namespaces as ns}
        <label class="check radio">
          <input
            type="radio"
            name="namespace"
            checked={filters.namespace === ns}
            onchange={() => patch({ namespace: ns })}
          />
          <span class="ns">{ns}</span>
        </label>
      {/each}
    </div>
  {/if}
</aside>

<style>
  .panel {
    width: 248px;
    flex: 0 0 248px;
    padding: 16px;
    border-right: 1px solid var(--border);
    background: var(--bg-elev);
    overflow-y: auto;
  }
  .group {
    margin-bottom: 22px;
  }
  .group h3 {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--fg-muted);
    font-weight: 700;
    margin: 0 0 8px 0;
  }
  .group-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 4px;
  }
  .group-head h3 { margin-bottom: 0; }
  .clear {
    background: none;
    border: none;
    color: var(--accent);
    font-size: 11px;
    padding: 0;
    cursor: pointer;
  }
  .clear:hover { text-decoration: underline; }

  .locales {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .locale {
    display: grid;
    grid-template-columns: 1fr auto auto;
    grid-template-areas:
      "code coverage counts"
      "bar bar bar";
    gap: 4px 8px;
    align-items: center;
    width: 100%;
    padding: 8px 10px;
    border: 1px solid transparent;
    border-radius: var(--radius);
    background: transparent;
    text-align: left;
  }
  .locale:hover {
    background: var(--row-hover);
  }
  .locale.active {
    background: var(--accent-soft);
    border-color: var(--accent);
  }
  .locale .code {
    grid-area: code;
    font-family: var(--mono);
    font-size: 13px;
    font-weight: 600;
    color: var(--fg);
  }
  .locale .coverage {
    grid-area: coverage;
    font-size: 11px;
    color: var(--fg-muted);
    font-variant-numeric: tabular-nums;
  }
  .locale .coverage.muted { color: var(--fg-subtle); }
  .locale .bar {
    grid-area: bar;
    height: 4px;
    background: var(--bg-sunken);
    border-radius: 999px;
    overflow: hidden;
  }
  .locale .fill {
    display: block;
    height: 100%;
    background: var(--accent);
    transition: width 200ms ease;
  }
  .locale.active .fill {
    background: var(--accent-strong);
  }
  .locale .counts {
    grid-area: counts;
    display: inline-flex;
    gap: 4px;
  }

  .search input {
    width: 100%;
    padding: 7px 10px;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--bg);
    color: var(--fg);
  }
  .search input::placeholder { color: var(--fg-subtle); }
  .search input:focus {
    outline: none;
    border-color: var(--accent);
  }

  .check {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 5px 0;
    cursor: pointer;
    color: var(--fg);
    font-size: 13px;
  }
  .check input {
    accent-color: var(--accent);
  }
  .check.radio .ns,
  .check.radio .ns-all {
    font-family: var(--mono);
    font-size: 12px;
  }
  .ns-all { color: var(--fg-muted); }

  .dot {
    display: inline-block;
    min-width: 16px;
    height: 16px;
    padding: 0 5px;
    border-radius: 999px;
    font-size: 10px;
    font-weight: 700;
    line-height: 16px;
    text-align: center;
    color: white;
    font-variant-numeric: tabular-nums;
  }
  .dot-missing { background: var(--danger); }
  .dot-stale { background: var(--warning); }
  .dot-locked { background: var(--accent); }
  .check .dot {
    width: 8px;
    min-width: 8px;
    height: 8px;
    padding: 0;
  }
</style>
