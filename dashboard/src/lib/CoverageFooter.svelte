<script lang="ts">
  import type { StatusRow } from './api';

  let {
    row,
    locale,
    visibleCount,
    totalCount,
    onJumpMissing,
    onJumpStale,
  }: {
    row: StatusRow | null;
    locale: string;
    visibleCount: number;
    totalCount: number;
    onJumpMissing: () => void;
    onJumpStale: () => void;
  } = $props();

  function pct(v: number): string {
    if (v === 1) return '100%';
    return `${(v * 100).toFixed(1)}%`;
  }
</script>

<footer>
  <div class="left">
    <span class="locale-chip">{locale}</span>
    {#if row}
      <span class="metric">
        <strong>{pct(row.coverage)}</strong>
        <span class="label">coverage</span>
      </span>
      <span class="bar" title={`${Math.round(row.coverage * 100)}%`}>
        <span class="fill" style:width={`${Math.round(row.coverage * 100)}%`}></span>
      </span>
      <span class="metric">
        <strong class:warn={row.missing > 0}>{row.missing}</strong>
        <span class="label">missing</span>
      </span>
      <span class="metric">
        <strong class:warn={row.stale > 0}>{row.stale}</strong>
        <span class="label">stale</span>
      </span>
      <span class="metric">
        <strong>{row.locked}</strong>
        <span class="label">locked</span>
      </span>
    {:else}
      <span class="muted">No coverage data for <code>{locale}</code></span>
    {/if}
  </div>

  <div class="right">
    <span class="count">{visibleCount} of {totalCount} shown</span>
    {#if row && row.missing > 0}
      <button type="button" class="btn btn-ghost" onclick={onJumpMissing}>
        Next missing <kbd>N</kbd>
      </button>
    {/if}
    {#if row && row.stale > 0}
      <button type="button" class="btn btn-ghost" onclick={onJumpStale}>
        Next stale <kbd>S</kbd>
      </button>
    {/if}
  </div>
</footer>

<style>
  footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 8px 20px;
    background: var(--bg-elev);
    border-top: 1px solid var(--border);
    font-size: 12px;
    color: var(--fg-muted);
  }
  .left, .right {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .locale-chip {
    font-family: var(--mono);
    background: var(--accent-soft);
    color: var(--accent-strong);
    padding: 3px 10px;
    border-radius: 999px;
    font-weight: 700;
    font-size: 11px;
  }
  .metric strong {
    color: var(--fg);
    font-weight: 700;
    margin-right: 4px;
    font-variant-numeric: tabular-nums;
  }
  .metric strong.warn { color: var(--warning); }
  .metric .label { color: var(--fg-muted); }
  .bar {
    display: inline-block;
    width: 120px;
    height: 5px;
    background: var(--bg-sunken);
    border-radius: 999px;
    overflow: hidden;
  }
  .bar .fill {
    display: block;
    height: 100%;
    background: var(--ok);
    transition: width 200ms ease;
  }
  .count {
    color: var(--fg-subtle);
    font-variant-numeric: tabular-nums;
  }
  .muted { color: var(--fg-subtle); }
  code {
    background: var(--bg-sunken);
    padding: 1px 5px;
    border-radius: 3px;
    font-family: var(--mono);
    font-size: 11px;
  }
  .btn {
    padding: 4px 10px;
    font-size: 12px;
  }
  .btn kbd {
    margin-left: 4px;
  }
</style>
