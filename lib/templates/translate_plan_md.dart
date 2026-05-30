// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/translate_plan.md`.

// dart format off
const String translatePlanMdTemplate = r'''# Dialect translate plan

You are an AI assistant. This file is your instruction manual for one
specific task: produce translations for the keys that are missing them
in `{{PROJECT_NAME}}`, refresh the ones whose English source changed
since they were translated, and flag the locked ones that have gone
stale.

Project: **{{PROJECT_NAME}}**
Source locale: `{{SOURCE_LOCALE}}`
Target locales: `{{TARGET_LOCALES}}`
Generated: {{GENERATED_AT}}

This file was written by `dialect translate`. Re-running that command
recomputes the work list below and overwrites this file. The full
convention lives in `dialect/dialect.yaml` — **read it before you
start**, along with `dialect/glossary.yaml`. If anything here conflicts
with those, they win.

---

## 1. Read first (in this order)

1. `dialect/dialect.yaml` — the convention, especially the `@key`
   metadata rules and any per-project tone / formality notes.
2. `dialect/glossary.yaml` — required term translations and the style
   guide (tone, per-locale formality). These are **not optional**: a
   translation that ignores a glossary term is wrong even if it reads
   well.
3. `dialect/source/{{SOURCE_LOCALE}}.arb` — the source strings and their
   `@key` descriptions. The description is what disambiguates meaning
   (e.g. "Book" the verb vs. the noun) — translate from the description,
   not the bare string.

---

## 2. The work list

Everything below was computed from the current project state. Each locale
may have up to three buckets:

- **Missing** — no translation yet. Translate them.
- **Stale** — a translation exists, but the English source changed since
  it was written. Re-translate against the current source, then delete
  that key's `@<key>` block in the translation file so the CLI re-stamps
  it as fresh (see §4).
- **Stale (locked)** — a human locked this translation and the source has
  since changed. **Review only — do not edit.**

Translate exactly the keys listed — don't go hunting for others, and
don't touch keys that aren't listed.

{{WORKLIST}}

---

## 3. How to translate each key

For every key under **Missing** or **Stale** for a locale:

- Read the source value and its `@key.description` / `context` in
  `dialect/source/{{SOURCE_LOCALE}}.arb`.
- Produce a natural translation in the target language — not a literal
  word-for-word gloss. Match the tone/formality in `glossary.yaml`.
- **Preserve every ICU placeholder and structure exactly.** A
  `{count, plural, …}` source must stay a plural in the translation,
  with all the CLDR categories the target locale requires
  (`zero/one/two/few/many/other` as applicable — Arabic needs all six,
  Japanese needs only `other`). Placeholder names (`{userName}`) are
  identifiers — never translate or rename them.
- Apply every relevant `glossary.yaml` term. If a glossary term appears
  in the source but you're using it non-literally, that's the
  developer's call — leave a note in your summary rather than silently
  diverging.
- Do **not** pass the English through unchanged. An identical-to-source
  value is the single most common failure mode and `dialect check`
  flags it.

For every key under **Stale** (unlocked): re-translate it against the
current source value, exactly as above. Then **delete that key's `@<key>`
block** in `dialect/translations/<locale>.arb` (it holds the old
`source_hash`). `dialect check --fix` re-stamps a fresh hash, marking the
translation current again. If you skip the delete, the key stays flagged
stale even though you fixed it — harmless, but the developer will see a
false warning.

For every key under **Stale (locked)**: **do not edit it.** A human
locked that translation and the source has since changed. List it in your
summary so the developer can decide whether to unlock and re-translate.
Overwriting a lock silently is never allowed.

---

## 4. Where to write

- Write values into `dialect/translations/<locale>.arb` for each target
  locale — one file per locale. Write keys and values; don't hand-write
  `@key` blocks. The CLI manages a tiny `source_hash` on each translation
  (provenance for staleness) — you only ever *delete* a stale key's
  `@<key>` block when re-translating it (per §3); you never author one.
- Do **not** copy descriptive metadata (`namespace`, `description`,
  `placeholders`) into translation files. That lives only in the source
  ARB; the CLI strips it from translations.
- Do **not** touch `dialect/source/{{SOURCE_LOCALE}}.arb`. Translating is
  not the time to change source strings or descriptions — that's
  `dialect describe`.
- You don't have to match sort order or formatting by hand — write the
  entries in any reasonable shape, then run `dialect check --fix` and
  the CLI normalizes them.

---

## 5. Hard guardrails

You **must not**:

- Modify, overwrite, or delete any entry marked `locked` in a
  translation file.
- Change source strings, descriptions, or any `@key` metadata.
- Add, rename, or delete keys. You only fill in values for the keys
  listed above.
- Drop, rename, or add ICU placeholders, or collapse a plural/select
  into a flat string.
- Invent keys that aren't in the source ARB.

---

## 6. Finalize (run these yourself)

You're driving the CLI from here. Run these in order from the project
root and only stop if one reports an error:

1. `dialect check --fix` — normalize formatting and surface structural
   problems (missing placeholders, missing plural categories,
   source-equal values) with file:line hints. Fix anything it flags as
   an error, then re-run.
2. `dialect sync` — propagate the new translations into the platform
   outputs (Flutter ARB, backend JSON).
3. `dialect check` — confirm a clean pass.

Then report a brief summary: how many keys you translated per locale,
any glossary terms you used non-literally (and why), and any **Stale
(locked)** keys the developer needs to review. Warnings that aren't
errors (e.g. a length-ratio outlier on a legitimately long language)
are for the developer to triage — surface them, don't paper over them.

The deterministic CLI work — formatting, sync, validation — is yours to
run; the developer's job is review.
''';
// dart format on
