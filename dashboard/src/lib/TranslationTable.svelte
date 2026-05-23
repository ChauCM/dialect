<script lang="ts">
  import type { GlossaryTerm, StringEntry } from './api';
  import GlossaryHighlight from './GlossaryHighlight.svelte';
  import LockToggle from './LockToggle.svelte';

  let {
    entries,
    sourceLocale,
    targetLocale,
    terms = [],
    onSave,
  }: {
    entries: StringEntry[];
    sourceLocale: string;
    targetLocale: string;
    terms?: GlossaryTerm[];
    onSave: (entry: StringEntry, next: { value: string; locked?: boolean }) => Promise<void>;
  } = $props();

  let editingKey = $state<string | null>(null);
  let draft = $state('');
  let saving = $state<string | null>(null);
  let error = $state<{ key: string; message: string } | null>(null);

  function startEdit(entry: StringEntry) {
    editingKey = entry.key;
    draft = entry.translation ?? '';
    error = null;
  }

  function cancelEdit() {
    editingKey = null;
    draft = '';
  }

  async function commit(entry: StringEntry) {
    if (draft === (entry.translation ?? '')) {
      cancelEdit();
      return;
    }
    saving = entry.key;
    try {
      await onSave(entry, { value: draft });
      editingKey = null;
    } catch (e) {
      error = { key: entry.key, message: (e as Error).message };
    } finally {
      saving = null;
    }
  }

  async function toggleLock(entry: StringEntry, next: boolean) {
    saving = entry.key;
    try {
      await onSave(entry, {
        value: entry.translation ?? entry.source,
        locked: next,
      });
    } catch (e) {
      error = { key: entry.key, message: (e as Error).message };
    } finally {
      saving = null;
    }
  }

  function onKey(e: KeyboardEvent, entry: StringEntry) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      void commit(entry);
    } else if (e.key === 'Escape') {
      e.preventDefault();
      cancelEdit();
    }
  }
</script>

<div class="wrap">
  <table>
    <colgroup>
      <col class="col-key" />
      <col class="col-source" />
      <col class="col-target" />
      <col class="col-actions" />
    </colgroup>
    <thead>
      <tr>
        <th>Key</th>
        <th>{sourceLocale}</th>
        <th>{targetLocale}</th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      {#each entries as entry (entry.key)}
        <tr class:missing={entry.missing} class:stale={entry.stale}>
          <td class="key">
            <code>{entry.key}</code>
            {#if entry.description}
              <p class="desc">{entry.description}</p>
            {/if}
          </td>
          <td class="source">
            <GlossaryHighlight text={entry.source} {terms} />
          </td>
          <td class="target">
            {#if editingKey === entry.key}
              <textarea
                value={draft}
                disabled={saving === entry.key}
                rows="2"
                oninput={(e) => (draft = (e.currentTarget as HTMLTextAreaElement).value)}
                onkeydown={(e) => onKey(e, entry)}
                onblur={() => void commit(entry)}
              ></textarea>
            {:else if entry.missing}
              <button
                type="button"
                class="add"
                onclick={() => startEdit(entry)}
              >
                ⚠ Add translation
              </button>
            {:else}
              <button
                type="button"
                class="value"
                onclick={() => startEdit(entry)}
              >
                {entry.translation}
              </button>
            {/if}
            {#if entry.stale}
              <span class="stale-tag" title="Source has changed since this was locked">
                stale
              </span>
            {/if}
            {#if error && error.key === entry.key}
              <p class="err">{error.message}</p>
            {/if}
          </td>
          <td class="actions">
            {#if !entry.missing}
              <LockToggle
                locked={entry.locked}
                onToggle={(next) => void toggleLock(entry, next)}
              />
            {/if}
          </td>
        </tr>
      {/each}
    </tbody>
  </table>

  {#if entries.length === 0}
    <p class="empty">No entries match these filters.</p>
  {/if}
</div>

<style>
  .wrap {
    flex: 1;
    overflow: auto;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
  }
  .col-key { width: 28%; }
  .col-source { width: 32%; }
  .col-target { width: 32%; }
  .col-actions { width: 8%; }

  thead th {
    text-align: left;
    padding: 8px 12px;
    border-bottom: 1px solid var(--border-strong);
    background: var(--bg-elev);
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--fg-muted);
    font-weight: 600;
    position: sticky;
    top: 0;
    z-index: 1;
  }
  tbody td {
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
    vertical-align: top;
    word-wrap: break-word;
  }
  tbody tr:hover { background: var(--row-hover); }
  tbody tr.missing td.target { color: var(--warning); }
  tbody tr.stale { background: var(--warning-soft); }

  .key code {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--accent);
    display: block;
  }
  .key .desc {
    color: var(--fg-muted);
    font-size: 12px;
    margin: 4px 0 0 0;
    line-height: 1.4;
  }

  .target button.value {
    background: transparent;
    border: 1px solid transparent;
    text-align: left;
    padding: 4px 6px;
    border-radius: 3px;
    width: 100%;
    display: block;
    color: var(--fg);
  }
  .target button.value:hover {
    border-color: var(--border-strong);
    background: var(--bg-elev);
  }
  .target button.add {
    background: var(--warning-soft);
    border: 1px dashed var(--warning);
    color: var(--warning);
    padding: 4px 8px;
    border-radius: 3px;
    font-size: 12px;
  }

  textarea {
    width: 100%;
    padding: 6px 8px;
    border: 1px solid var(--accent);
    border-radius: 3px;
    background: var(--bg-elev);
    min-height: 36px;
    line-height: 1.4;
  }
  textarea:focus { outline: none; }

  .stale-tag {
    display: inline-block;
    margin-left: 8px;
    background: var(--warning);
    color: white;
    font-size: 10px;
    text-transform: uppercase;
    padding: 1px 5px;
    border-radius: 3px;
    letter-spacing: 0.05em;
  }
  .err {
    color: var(--danger);
    font-size: 12px;
    margin: 4px 0 0 0;
  }
  .empty {
    text-align: center;
    color: var(--fg-subtle);
    padding: 48px 0;
  }
</style>
