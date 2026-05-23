<script lang="ts">
  import type { StatusRow } from './api';

  let { row, locale }: { row: StatusRow | null; locale: string } = $props();

  function pct(v: number): string {
    if (v === 1) return '100%';
    return `${(v * 100).toFixed(1)}%`;
  }
</script>

<footer>
  {#if row}
    <span class="locale">{locale}</span>
    <span class="metric">
      <strong>{pct(row.coverage)}</strong>
      coverage
    </span>
    <span class="metric">
      <strong class:warn={row.missing > 0}>{row.missing}</strong>
      missing
    </span>
    <span class="metric">
      <strong class:warn={row.stale > 0}>{row.stale}</strong>
      stale
    </span>
    <span class="metric">
      <strong>{row.locked}</strong>
      locked
    </span>
  {:else}
    <span class="muted">No coverage data for <code>{locale}</code></span>
  {/if}
</footer>

<style>
  footer {
    display: flex;
    gap: 24px;
    align-items: center;
    padding: 10px 24px;
    background: var(--bg-elev);
    border-top: 1px solid var(--border);
    font-size: 13px;
    color: var(--fg-muted);
  }
  .locale {
    font-family: var(--mono);
    background: var(--accent-soft);
    color: var(--accent);
    padding: 2px 8px;
    border-radius: 4px;
    font-weight: 600;
  }
  .metric strong {
    color: var(--fg);
    font-weight: 600;
    margin-right: 4px;
  }
  .metric strong.warn {
    color: var(--warning);
  }
  .muted {
    color: var(--fg-subtle);
  }
  code {
    background: var(--row-hover);
    padding: 1px 4px;
    border-radius: 3px;
    font-family: var(--mono);
    font-size: 12px;
  }
</style>
