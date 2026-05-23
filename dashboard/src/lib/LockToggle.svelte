<script lang="ts">
  let {
    locked,
    disabled = false,
    onToggle,
  }: {
    locked: boolean;
    disabled?: boolean;
    onToggle: (next: boolean) => void;
  } = $props();
</script>

<button
  type="button"
  class="lock"
  class:locked
  {disabled}
  title={locked ? 'Locked — click to unlock' : 'Click to lock to current source'}
  onclick={() => onToggle(!locked)}
>
  {locked ? '🔒' : '🔓'}
</button>

<style>
  .lock {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 3px 8px;
    font-size: 14px;
    color: var(--fg-subtle);
    line-height: 1;
    transition: all 80ms ease;
  }
  .lock.locked {
    color: var(--accent-strong);
    border-color: var(--accent);
    background: var(--accent-soft);
  }
  .lock:hover:not([disabled]) {
    border-color: var(--border-strong);
    background: var(--row-hover);
  }
  .lock[disabled] {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
