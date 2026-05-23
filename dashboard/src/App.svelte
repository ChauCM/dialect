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
    type StatusRow,
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
  let theme = $state<'light' | 'dark'>(initialTheme());
  let tableRef = $state<TranslationTable | null>(null);
  let filters = $state({
    missing: false,
    locked: false,
    stale: false,
    namespace: null as string | null,
    search: '',
  });

  $effect(() => {
    document.documentElement.dataset.theme = theme;
    try {
      localStorage.setItem('dialect-theme', theme);
    } catch {
      /* storage may be unavailable */
    }
  });

  function initialTheme(): 'light' | 'dark' {
    try {
      const saved = localStorage.getItem('dialect-theme');
      if (saved === 'dark' || saved === 'light') return saved;
    } catch {
      /* ignore */
    }
    return matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

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

  let allLocales = $derived.by(() => {
    if (!config) return [] as string[];
    return [config.source_locale, ...config.target_locales];
  });

  let statusByLocale = $derived.by(() => {
    const map: Record<string, StatusRow> = {};
    for (const row of status?.rows ?? []) {
      map[row.locale] = row;
    }
    // Source locale is always 100% complete by definition.
    if (config && !map[config.source_locale]) {
      const total = strings?.entries.length ?? 0;
      map[config.source_locale] = {
        locale: config.source_locale,
        coverage: 1,
        missing: 0,
        stale: 0,
        locked: total,
      };
    }
    return map;
  });

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
    activeLocale ? statusByLocale[activeLocale] ?? null : null,
  );

  let totalCount = $derived(strings?.entries.length ?? 0);

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
    const [s, st] = await Promise.all([
      fetchStrings(activeLocale),
      fetchStatus(),
    ]);
    strings = s;
    status = st;
  }

  function focusNext(filter: (e: StringEntry) => boolean) {
    const target = visibleEntries.find(filter);
    if (!target) return;
    const el = document.querySelector(
      `[data-row-key="${CSS.escape(target.key)}"]`,
    );
    el?.scrollIntoView({ block: 'center', behavior: 'smooth' });
    (el?.querySelector('.target button') as HTMLButtonElement | null)?.click();
  }
</script>

<header>
  <div class="brand">
    <span class="logo" aria-hidden="true">◆</span>
    <div class="brand-text">
      <strong>Dialect</strong>
      {#if config}<span class="project">{config.project_name}</span>{/if}
    </div>
  </div>

  <div class="header-actions">
    {#if config && activeLocale}
      <div class="active-locale">
        <span class="label">Editing</span>
        <code class="locale-code">{activeLocale}</code>
        {#if activeLocale === config.source_locale}
          <span class="pill pill-locked">Source</span>
        {/if}
      </div>
    {/if}
    <button
      type="button"
      class="btn btn-ghost theme"
      title={theme === 'dark' ? 'Switch to light' : 'Switch to dark'}
      onclick={() => (theme = theme === 'dark' ? 'light' : 'dark')}
    >
      {theme === 'dark' ? '☀' : '☾'}
    </button>
  </div>
</header>

<main>
  {#if config}
    <FilterPanel
      {filters}
      {namespaces}
      locales={allLocales}
      {statusByLocale}
      {activeLocale}
      onChange={(next) => (filters = next)}
      onLocaleChange={(locale) => (activeLocale = locale)}
    />
  {/if}
  <section class="content">
    {#if loadError}
      <p class="err">Failed to load: {loadError}</p>
    {:else if !config || !strings || !activeLocale}
      <p class="loading">Loading…</p>
    {:else}
      <TranslationTable
        bind:this={tableRef}
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
  <CoverageFooter
    row={currentStatus}
    locale={activeLocale}
    visibleCount={visibleEntries.length}
    {totalCount}
    onJumpMissing={() => focusNext((e) => e.missing)}
    onJumpStale={() => focusNext((e) => e.stale)}
  />
{/if}

<style>
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 20px;
    background: var(--bg-elev);
    border-bottom: 1px solid var(--border);
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .logo {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: 8px;
    background: linear-gradient(135deg, var(--accent), var(--accent-strong));
    color: var(--accent-fg);
    font-size: 14px;
  }
  .brand-text strong {
    color: var(--fg);
    font-size: 15px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }
  .brand-text .project {
    margin-left: 8px;
    color: var(--fg-muted);
    font-size: 13px;
  }
  .header-actions {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .active-locale {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 4px 10px;
    border-radius: 999px;
    background: var(--bg-sunken);
    font-size: 12px;
    color: var(--fg-muted);
  }
  .active-locale .label {
    color: var(--fg-subtle);
  }
  .active-locale .locale-code {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--fg);
    font-weight: 600;
  }
  .theme {
    padding: 5px 10px;
    font-size: 16px;
    line-height: 1;
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
    padding: 64px 24px;
    color: var(--fg-muted);
  }
  .err {
    color: var(--danger);
  }
</style>
