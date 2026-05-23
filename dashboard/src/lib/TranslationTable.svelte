<script lang="ts">
  import type { GlossaryTerm, StringEntry } from './api';
  import EntryEditor from './EntryEditor.svelte';
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
  let togglingKey = $state<string | null>(null);
  let toggleError = $state<{ key: string; message: string } | null>(null);

  let isSourceView = $derived(targetLocale === sourceLocale);

  function startEdit(entry: StringEntry) {
    editingKey = entry.key;
    toggleError = null;
  }

  function stopEdit() {
    editingKey = null;
  }

  async function handleEditorSave(
    entry: StringEntry,
    next: { value: string; locked?: boolean },
  ) {
    await onSave(entry, next);
    editingKey = null;
  }

  async function toggleLock(entry: StringEntry, next: boolean) {
    togglingKey = entry.key;
    toggleError = null;
    try {
      await onSave(entry, {
        value: entry.translation ?? entry.source,
        locked: next,
      });
    } catch (e) {
      toggleError = { key: entry.key, message: (e as Error).message };
    } finally {
      togglingKey = null;
    }
  }

  function jumpToNext(filter: (e: StringEntry) => boolean) {
    const start = editingKey
      ? entries.findIndex((e) => e.key === editingKey) + 1
      : 0;
    const idx = entries.findIndex((e, i) => i >= start && filter(e));
    const wrapped = idx === -1 ? entries.findIndex(filter) : idx;
    if (wrapped !== -1) {
      editingKey = entries[wrapped].key;
      // Scroll into view on next tick.
      queueMicrotask(() => {
        const el = document.querySelector(
          `[data-row-key="${CSS.escape(entries[wrapped].key)}"]`,
        );
        el?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      });
    }
  }

  function onTableKey(e: KeyboardEvent) {
    if (editingKey) return;
    if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
      return;
    }
    if (e.key === 'n' || e.key === 'N') {
      e.preventDefault();
      jumpToNext((entry) => entry.missing);
    } else if (e.key === 's' || e.key === 'S') {
      e.preventDefault();
      jumpToNext((entry) => entry.stale);
    }
  }
</script>

<svelte:window onkeydown={onTableKey} />

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
        <th>{sourceLocale} <span class="muted">(source)</span></th>
        <th>{targetLocale}</th>
        <th class="th-actions"></th>
      </tr>
    </thead>
    <tbody>
      {#each entries as entry (entry.key)}
        <tr
          data-row-key={entry.key}
          class:missing={entry.missing}
          class:stale={entry.stale}
          class:editing={editingKey === entry.key}
        >
          <td class="key">
            <code>{entry.key}</code>
            {#if entry.namespace}
              <span class="ns-tag">{entry.namespace}</span>
            {/if}
            {#if entry.description}
              <p class="desc">{entry.description}</p>
            {/if}
            {#if entry.context}
              <p class="ctx" title="Context">↳ {entry.context}</p>
            {/if}
            <div class="pills">
              {#if entry.missing}<span class="pill pill-missing">Missing</span>{/if}
              {#if entry.stale}<span class="pill pill-stale">Stale</span>{/if}
              {#if entry.locked && !entry.missing}<span class="pill pill-locked">Locked</span>{/if}
            </div>
          </td>
          <td class="source">
            <GlossaryHighlight text={entry.source} {terms} />
          </td>
          <td class="target">
            {#if editingKey === entry.key}
              <EntryEditor
                {entry}
                isSource={isSourceView}
                onSave={(next) => handleEditorSave(entry, next)}
                onCancel={stopEdit}
              />
            {:else if entry.missing}
              <button
                type="button"
                class="add"
                onclick={() => startEdit(entry)}
              >
                + Add translation
              </button>
            {:else}
              <button
                type="button"
                class="value"
                onclick={() => startEdit(entry)}
                title="Click to edit"
              >
                <GlossaryHighlight text={entry.translation ?? ''} {terms} />
              </button>
            {/if}
            {#if toggleError && toggleError.key === entry.key}
              <p class="err">{toggleError.message}</p>
            {/if}
          </td>
          <td class="actions">
            {#if !entry.missing && !isSourceView && editingKey !== entry.key}
              <LockToggle
                locked={entry.locked}
                disabled={togglingKey === entry.key}
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
  .col-key { width: 26%; }
  .col-source { width: 30%; }
  .col-target { width: 38%; }
  .col-actions { width: 6%; }

  thead th {
    text-align: left;
    padding: 10px 14px;
    border-bottom: 1px solid var(--border-strong);
    background: var(--bg-elev);
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
    font-weight: 700;
    position: sticky;
    top: 0;
    z-index: 1;
  }
  thead th .muted {
    color: var(--fg-subtle);
    font-weight: 400;
    text-transform: none;
    letter-spacing: 0;
    margin-left: 4px;
  }
  tbody td {
    padding: 12px 14px;
    border-bottom: 1px solid var(--border);
    vertical-align: top;
    word-wrap: break-word;
  }
  tbody tr {
    transition: background 80ms ease;
  }
  tbody tr:hover { background: var(--row-hover); }
  tbody tr.editing { background: var(--accent-soft); }
  tbody tr.editing:hover { background: var(--accent-soft); }
  tbody tr.stale { background: color-mix(in srgb, var(--warning-soft) 40%, transparent); }

  .key code {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--accent-strong);
    display: inline-block;
    margin-right: 6px;
    word-break: break-all;
  }
  .key .ns-tag {
    display: inline-block;
    font-family: var(--mono);
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 999px;
    background: var(--bg-sunken);
    color: var(--fg-muted);
    vertical-align: middle;
  }
  .key .desc {
    color: var(--fg-muted);
    font-size: 12px;
    margin: 6px 0 0 0;
    line-height: 1.4;
  }
  .key .ctx {
    color: var(--fg-subtle);
    font-size: 11px;
    margin: 3px 0 0 0;
    line-height: 1.4;
  }
  .key .pills {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 8px;
  }

  .target button.value {
    background: transparent;
    border: 1px solid transparent;
    text-align: left;
    padding: 6px 8px;
    border-radius: var(--radius);
    width: 100%;
    display: block;
    color: var(--fg);
    line-height: 1.45;
  }
  .target button.value:hover {
    border-color: var(--border);
    background: var(--bg-elev);
  }
  .target button.add {
    background: var(--danger-soft);
    border: 1px dashed var(--danger);
    color: var(--danger);
    padding: 8px 12px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 500;
  }
  .target button.add:hover {
    background: var(--danger);
    color: white;
  }

  .err {
    color: var(--danger);
    font-size: 12px;
    margin: 6px 0 0 0;
  }
  .empty {
    text-align: center;
    color: var(--fg-subtle);
    padding: 64px 0;
    font-size: 14px;
  }

  .th-actions {
    text-align: right;
  }
  .actions {
    text-align: right;
  }
</style>
