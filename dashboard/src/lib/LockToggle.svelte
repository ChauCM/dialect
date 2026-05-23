<script lang="ts">
  let {
    locked,
    onToggle,
  }: {
    locked: boolean;
    onToggle: (next: boolean) => void;
  } = $props();
</script>

<button
  type="button"
  class="lock"
  class:locked
  title={locked ? 'Locked — click to unlock' : 'Click to lock'}
  onclick={() => onToggle(!locked)}
>
  {locked ? '🔒' : '🔓'}
</button>

<style>
  .lock {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 14px;
    color: var(--fg-subtle);
    line-height: 1;
  }
  .lock.locked {
    color: var(--accent);
    border-color: var(--accent);
    background: var(--accent-soft);
  }
  .lock:hover {
    border-color: var(--border-strong);
  }
</style>
