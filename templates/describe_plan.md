# Dialect describe plan

You are an AI assistant. This file is your instruction manual for one
specific task: backfill `@description` (and, where appropriate,
`context` and `placeholders`) for keys in
`dialect/source/{{SOURCE_LOCALE}}.arb` that are missing them.

Project: **{{PROJECT_NAME}}**
Source locale: `{{SOURCE_LOCALE}}`
Target locales: `{{TARGET_LOCALES}}`
Look for callsites under: `{{PATH}}`
Generated: {{GENERATED_AT}}

This file was written by `dialect describe`. Re-running that command
will overwrite this file. The full convention lives in
`dialect/dialect.yaml` — **read it before you start**. The sections
below excerpt the rules that govern this task; if anything here
conflicts with `dialect.yaml`, `dialect.yaml` wins.

---

## 1. Read first (in this order)

1. `dialect/dialect.yaml` — the full convention, especially the
   `@key metadata` section (what a good description looks like).
2. `dialect/source/{{SOURCE_LOCALE}}.arb` — the keys you'll be
   editing. Pay attention to the `@key` blocks that already have
   good descriptions — match their tone, length, and level of
   detail.
3. The code under `{{PATH}}` — read the callsites that reference each
   key so your descriptions are grounded in how the string is
   actually used.

---

## 2. Your job

1. Find every entry in `dialect/source/{{SOURCE_LOCALE}}.arb` whose
   `@key` block is missing OR whose `description` is missing,
   empty, or generic (e.g. `"description": "Book now button"`).
2. For each such key:
   - Locate one or more callsites in the source code under
     `{{PATH}}` that reference the key. The exact way the key is
     referenced depends on the framework (`AppLocalizations.of(...)`
     in Flutter, `IStringLocalizer` in C#, `_()` in Django, …).
     Search by the key string itself; it's the most reliable hook.
   - Read enough surrounding code to understand: what screen the
     string appears on, what the user is doing at that moment, what
     `Book` / `Trip` / similar polysemous words refer to in this
     callsite.
   - Write a description that gives that context. The bar is:
     **a translator who has never seen the app can pick the right
     word from the description alone**.
     - Bad: `"description": "Book now button"`
     - Good: `"description": "CTA on the checkout screen for
       confirming a paid reservation. 'Book' is a verb meaning
       'make a reservation', NOT a physical book."`
   - If the same word can mean different things in different
     places, set `context: "<screen_or_feature>"`.
   - If the value has ICU placeholders, ensure the `@key.placeholders`
     map describes each one (`type` + a short description of what
     it stands for).

---

## 3. Where to write

- **Only** `dialect/source/{{SOURCE_LOCALE}}.arb`. You're editing the
  `@key` blocks; do not change any string value, do not rename any
  key, do not add or remove keys.
- Do **not** add `@key` blocks to translation files
  (`dialect/translations/<locale>.arb`). Metadata lives only in the
  source ARB; the CLI strips it from translations.
- Do not modify source code under `{{PATH}}`. You may **read** it to
  derive descriptions; you may not edit it.

You don't have to remember sort order or formatting — edit entries in
any reasonable shape, then run `dialect check --fix` and the CLI
normalizes them.

---

## 4. Hard guardrails

You **must not**:

- Change any string value (the `"key": "value"` line). This task is
  about metadata only.
- Rename, add, or delete keys.
- Modify any file outside `dialect/source/{{SOURCE_LOCALE}}.arb`.
- Modify source code at `{{PATH}}` — read only.
- Re-translate strings. `dialect translate` is a separate task.
- Invent new `@key` metadata fields outside the convention.

---

## 5. When you're done

1. Run `dialect check --fix` from the project root. It will normalize
   formatting and flag any structural problems.
2. Fix anything `dialect check` reports as an error. Warnings are
   fine to leave for the developer to triage.
3. Report a brief summary: how many descriptions you added or
   improved, anything you couldn't ground in a callsite (those need
   the developer's input), anything that looked like a stale key
   (no callsite at all) that the developer should review.

Do **not** run `dialect translate` or `dialect sync` — those are the
developer's calls.
