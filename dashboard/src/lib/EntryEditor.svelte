<script lang="ts">
  import type { StringEntry } from './api';

  let {
    entry,
    isSource,
    onSave,
    onCancel,
  }: {
    entry: StringEntry;
    isSource: boolean;
    onSave: (next: { value: string; locked?: boolean }) => Promise<void>;
    onCancel: () => void;
  } = $props();

  let savedValue = $derived(entry.translation ?? '');
  let draft = $state('');
  let lockedDraft = $state(false);
  let saving = $state(false);
  let error = $state<string | null>(null);
  let textareaEl = $state<HTMLTextAreaElement | null>(null);

  // Initialize draft + lock state from the entry. Re-runs if the
  // parent ever reuses this editor for a different key.
  $effect(() => {
    draft = entry.translation ?? '';
    lockedDraft = entry.locked;
    error = null;
  });

  $effect(() => {
    if (textareaEl) {
      textareaEl.focus();
      textareaEl.setSelectionRange(draft.length, draft.length);
      autoResize(textareaEl);
    }
  });

  function autoResize(el: HTMLTextAreaElement) {
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 240)}px`;
  }

  let dirty = $derived(
    draft !== savedValue || lockedDraft !== entry.locked,
  );

  let placeholders = $derived.by(() => {
    const keys = Object.keys(entry.placeholders ?? {});
    return keys;
  });

  let placeholderStatus = $derived.by(() => {
    return placeholders.map((name) => ({
      name,
      present: draft.includes(`{${name}}`),
    }));
  });

  let missingPlaceholders = $derived(
    placeholderStatus.filter((p) => !p.present).map((p) => p.name),
  );

  async function commit() {
    if (!dirty) {
      onCancel();
      return;
    }
    saving = true;
    error = null;
    try {
      const next: { value: string; locked?: boolean } = { value: draft };
      if (!isSource && lockedDraft !== entry.locked) {
        next.locked = lockedDraft;
      }
      await onSave(next);
    } catch (e) {
      error = (e as Error).message;
    } finally {
      saving = false;
    }
  }

  function revert() {
    draft = savedValue;
    lockedDraft = entry.locked;
    error = null;
    if (textareaEl) autoResize(textareaEl);
  }

  function copySource() {
    draft = entry.source;
    if (textareaEl) {
      autoResize(textareaEl);
      textareaEl.focus();
    }
  }

  function clearDraft() {
    draft = '';
    if (textareaEl) {
      autoResize(textareaEl);
      textareaEl.focus();
    }
  }

  function onKey(e: KeyboardEvent) {
    // Cmd/Ctrl+Enter or Cmd/Ctrl+S → save. Plain Enter inserts newline
    // (translations sometimes need them); Esc cancels.
    if ((e.metaKey || e.ctrlKey) && (e.key === 'Enter' || e.key === 's')) {
      e.preventDefault();
      void commit();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      onCancel();
    }
  }

  function onInput(e: Event) {
    const el = e.currentTarget as HTMLTextAreaElement;
    draft = el.value;
    autoResize(el);
  }
</script>

<div class="editor">
  <textarea
    bind:this={textareaEl}
    value={draft}
    disabled={saving}
    rows="2"
    placeholder={isSource ? 'Source text…' : 'Translation…'}
    oninput={onInput}
    onkeydown={onKey}
  ></textarea>

  <div class="meta">
    <span class="char-count" class:warn={draft.length > 200}>
      {draft.length} chars
    </span>
    {#if placeholders.length > 0}
      <span class="placeholders">
        Placeholders:
        {#each placeholderStatus as p}
          <code class:missing={!p.present} title={p.present ? 'present' : 'missing in draft'}>
            {`{${p.name}}`}
          </code>
        {/each}
      </span>
    {/if}
    {#if !isSource}
      <label class="lock-toggle">
        <input
          type="checkbox"
          checked={lockedDraft}
          onchange={(e) => (lockedDraft = (e.currentTarget as HTMLInputElement).checked)}
        />
        <span>Lock to current source</span>
      </label>
    {/if}
  </div>

  {#if missingPlaceholders.length > 0 && draft.length > 0}
    <p class="warn-line">
      ⚠ Missing placeholder{missingPlaceholders.length === 1 ? '' : 's'}:
      <code>{missingPlaceholders.map((n) => `{${n}}`).join(' ')}</code>
    </p>
  {/if}

  {#if error}
    <p class="err">{error}</p>
  {/if}

  <div class="actions">
    <div class="left">
      <button type="button" class="btn btn-ghost" onclick={copySource} disabled={saving}>
        Copy source
      </button>
      <button
        type="button"
        class="btn btn-ghost"
        onclick={clearDraft}
        disabled={saving || draft.length === 0}
      >
        Clear
      </button>
    </div>
    <div class="right">
      <button
        type="button"
        class="btn btn-ghost btn-danger"
        onclick={revert}
        disabled={saving || !dirty}
        title="Revert to last saved value"
      >
        Revert
      </button>
      <button type="button" class="btn" onclick={onCancel} disabled={saving}>
        Cancel
        <kbd>Esc</kbd>
      </button>
      <button
        type="button"
        class="btn btn-primary"
        onclick={commit}
        disabled={saving || !dirty}
      >
        {saving ? 'Saving…' : 'Save'}
        <kbd>⌘↵</kbd>
      </button>
    </div>
  </div>
</div>

<style>
  .editor {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 10px;
    border: 1px solid var(--accent);
    border-radius: var(--radius);
    background: var(--bg-elev);
    box-shadow: var(--shadow-md);
  }
  textarea {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--bg-sunken);
    min-height: 44px;
    line-height: 1.45;
    font-size: 14px;
  }
  textarea:focus {
    outline: none;
    border-color: var(--accent);
    background: var(--bg-elev);
  }
  .meta {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 12px;
    font-size: 12px;
    color: var(--fg-muted);
  }
  .char-count {
    font-variant-numeric: tabular-nums;
  }
  .char-count.warn {
    color: var(--warning);
  }
  .placeholders {
    display: inline-flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 4px;
  }
  .placeholders code {
    font-family: var(--mono);
    font-size: 11px;
    padding: 1px 5px;
    border-radius: 3px;
    background: var(--accent-soft);
    color: var(--accent-strong);
  }
  .placeholders code.missing {
    background: var(--danger-soft);
    color: var(--danger);
  }
  .lock-toggle {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-left: auto;
    cursor: pointer;
    color: var(--fg-muted);
  }
  .lock-toggle input {
    accent-color: var(--accent);
  }
  .warn-line {
    margin: 0;
    font-size: 12px;
    color: var(--warning);
  }
  .warn-line code {
    font-family: var(--mono);
    font-size: 11px;
  }
  .err {
    margin: 0;
    color: var(--danger);
    font-size: 12px;
  }
  .actions {
    display: flex;
    justify-content: space-between;
    gap: 8px;
    margin-top: 2px;
  }
  .actions .left,
  .actions .right {
    display: flex;
    gap: 6px;
  }
  .actions kbd {
    margin-left: 4px;
  }
</style>
