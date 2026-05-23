<script lang="ts">
  import type { GlossaryTerm } from './api';

  let { text, terms = [] }: { text: string; terms?: GlossaryTerm[] } = $props();

  // Find every whole-word glossary term in `text`. Highlight each
  // occurrence with a styled span; non-matches pass through verbatim.
  // Word boundary uses simple ASCII regex — glossary terms are
  // English source-locale words.
  type Segment = { text: string; term?: GlossaryTerm };

  function segment(text: string, terms: GlossaryTerm[]): Segment[] {
    if (terms.length === 0) return [{ text }];
    // Build a single regex with a capture group per term — earliest
    // longest match wins. Escape special regex chars in term text.
    const escaped = terms
      .map((t) => t.term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
      .join('|');
    const re = new RegExp(`\\b(${escaped})\\b`, 'gi');
    const out: Segment[] = [];
    let last = 0;
    let m: RegExpExecArray | null;
    while ((m = re.exec(text)) !== null) {
      if (m.index > last) out.push({ text: text.slice(last, m.index) });
      const matchedTerm = terms.find(
        (t) => t.term.toLowerCase() === m![1].toLowerCase(),
      );
      out.push({ text: m[1], term: matchedTerm });
      last = m.index + m[1].length;
    }
    if (last < text.length) out.push({ text: text.slice(last) });
    return out;
  }

  let segments = $derived(segment(text, terms));
</script>

{#each segments as seg}
  {#if seg.term}
    <span
      class="gloss"
      title={`Glossary term — meaning: ${seg.term.meaning || '(none)'}`}
    >{seg.text}</span>
  {:else}
    {seg.text}
  {/if}
{/each}

<style>
  .gloss {
    background: var(--warning-soft);
    color: var(--warning);
    border-radius: 3px;
    padding: 0 2px;
    font-weight: 500;
  }
</style>
