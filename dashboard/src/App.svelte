<script lang="ts">
  import {
    fetchConfig,
    fetchStrings,
    fetchGlossary,
    fetchStatus,
    putString,
    type DialectConfig,
    type GlossaryTerm,
    type StringEntry,
    type StringsPayload,
    type StatusPayload,
  } from './lib/api';
  import FilterPanel from './lib/FilterPanel.svelte';
  import TranslationTable from './lib/TranslationTable.svelte';
  import CoverageFooter from './lib/CoverageFooter.svelte';

  let config = $state<DialectConfig | null>(null);
  let strings = $state<StringsPayload | null>(null);
  let status = $state<StatusPayload | null>(null);
  let terms = $state<GlossaryTerm[]>([]);
  let activeLocale = $state<string | null>(null);
  let loadError = $state<string | null>(null);
  let filters = $state({
    missing: false,
    locked: false,
    stale: false,
    namespace: null as string | null,
    search: '',
  });

  // Initial bootstrap.
  $effect(() => {
    void bootstrap();
  });

  async function bootstrap() {
    try {
      const [c, g, s] = await Promise.all([
        fetchConfig(),
        fetchGlossary(),
        fetchStatus(),
      ]);
      config = c;
      terms = g.terms;
      status = s;
      activeLocale = c.target_locales[0] ?? c.source_locale;
    } catch (e) {
      loadError = (e as Error).message;
    }
  }

  // Re-fetch strings whenever the active locale changes.
  $effect(() => {
    if (!activeLocale) return;
    const locale = activeLocale;
    void fetchStrings(locale)
      .then((payload) => {
        strings = payload;
      })
      .catch((e) => {
        loadError = (e as Error).message;
      });
  });

  // Namespaces shown in the filter panel come from the loaded strings.
  let namespaces = $derived.by(() => {
    if (!strings) return [] as string[];
    const set = new Set<string>();
    for (const entry of strings.entries) {
      if (entry.namespace) set.add(entry.namespace);
    }
    return [...set].sort();
  });

  let visibleEntries = $derived.by(() => {
    if (!strings) return [] as StringEntry[];
    const q = filters.search.trim().toLowerCase();
    return strings.entries.filter((entry) => {
      if (filters.missing && !entry.missing) return false;
      if (filters.locked && !entry.locked) return false;
      if (filters.stale && !entry.stale) return false;
      if (filters.namespace && entry.namespace !== filters.namespace) return false;
      if (q) {
        const haystack = `${entry.key} ${entry.source} ${entry.translation ?? ''}`.toLowerCase();
        if (!haystack.includes(q)) return false;
      }
      return true;
    });
  });

  let currentStatus = $derived(
    status?.rows.find((r) => r.locale === activeLocale) ?? null,
  );

  async function handleSave(
    entry: StringEntry,
    next: { value: string; locked?: boolean },
  ) {
    if (!activeLocale) return;
    await putString(entry.key, {
      locale: activeLocale,
      value: next.value,
      ...(next.locked !== undefined ? { locked: next.locked } : {}),
    });
    // Re-fetch strings + status so coverage updates and stale/locked
    // indicators refresh.
    const [s, st] = await Promise.all([
      fetchStrings(activeLocale),
      fetchStatus(),
    ]);
    strings = s;
    status = st;
  }
</script>

<header>
  <div class="brand">
    <strong>Dialect Review</strong>
    {#if config}<span class="project">{config.project_name}</span>{/if}
  </div>
  {#if config && activeLocale !== null}
    <label class="locale">
      <span>Locale</span>
      <select
        value={activeLocale}
        onchange={(e) => (activeLocale = (e.currentTarget as HTMLSelectElement).value)}
      >
        {#each config.target_locales as locale}
          <option value={locale}>{locale}</option>
        {/each}
      </select>
    </label>
  {/if}
</header>

<main>
  <FilterPanel
    {filters}
    {namespaces}
    onChange={(next) => (filters = next)}
  />
  <section class="content">
    {#if loadError}
      <p class="err">Failed to load: {loadError}</p>
    {:else if !config || !strings || !activeLocale}
      <p class="loading">Loading…</p>
    {:else}
      <TranslationTable
        entries={visibleEntries}
        sourceLocale={config.source_locale}
        targetLocale={activeLocale}
        {terms}
        onSave={handleSave}
      />
    {/if}
  </section>
</main>

{#if activeLocale}
  <CoverageFooter row={currentStatus} locale={activeLocale} />
{/if}

<style>
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 24px;
    background: var(--bg-elev);
    border-bottom: 1px solid var(--border-strong);
  }
  .brand strong {
    color: var(--accent);
    font-size: 15px;
    font-weight: 700;
  }
  .brand .project {
    margin-left: 12px;
    color: var(--fg-muted);
    font-size: 13px;
  }
  .locale {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: var(--fg-muted);
  }
  .locale select {
    padding: 4px 8px;
    border: 1px solid var(--border-strong);
    border-radius: 4px;
    background: var(--bg);
    font-family: var(--mono);
    font-size: 13px;
  }
  main {
    flex: 1;
    display: flex;
    overflow: hidden;
  }
  .content {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  .loading, .err {
    text-align: center;
    padding: 48px;
    color: var(--fg-muted);
  }
  .err {
    color: var(--danger);
  }
</style>
