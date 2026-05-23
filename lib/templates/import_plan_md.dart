// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/import_plan.md`.

// dart format off
const String importPlanMdTemplate = r'''# Dialect import plan

You are an AI assistant. This file is your instruction manual for one
specific task: import existing localization strings at `{{PATH}}` (format:
`{{FROM}}`) into the Dialect convention.

Project: **{{PROJECT_NAME}}**
Source locale: `{{SOURCE_LOCALE}}`
Target locales: `{{TARGET_LOCALES}}`
Current namespaces: `{{NAMESPACES}}`
Generated: {{GENERATED_AT}}

This file was written by `dialect import --from {{FROM}} --path {{PATH}}`.
Re-running that command will overwrite this file. The full convention
lives in `dialect/dialect.yaml` — **read it before you start**. The
sections below excerpt the rules that govern this task; if anything here
conflicts with `dialect.yaml`, `dialect.yaml` wins.

---

## 1. Read first (in this order)

1. `dialect/dialect.yaml` — the full convention (key style, plural rules,
   "what NOT to extract" list, glossary expectations).
2. `dialect/glossary.yaml` — term-by-term style/inflection rules.
3. `dialect/source/{{SOURCE_LOCALE}}.arb` — keys that already exist.
   **You will not overwrite these.** Existing keys are the product of
   earlier decisions; only add new keys.
4. The files at `{{PATH}}` — your input.

---

## 2. Your job

For every string at `{{PATH}}`:

1. Decide whether it belongs in Dialect at all. Skip strings that are
   data, not copy (names, emails, URLs, currency amounts, dates,
   language self-names, brand names, placeholder/demo content). See the
   "What NOT to extract" section of `dialect/dialect.yaml`.
2. Rename the key to flat `camelCaseKey` (a valid Dart identifier).
   No dots, dashes, or leading digits — `flutter gen-l10n` won't accept
   them. Group keys via `@key.namespace` metadata (see step 3), not via
   key prefixes.
3. Add full `@key` metadata to the SOURCE ARB:
   - `namespace` — which logical group this key belongs to (e.g.
     `checkout`, `common`). Pick an existing namespace when it fits
     (see `Current namespaces` above and `platforms.<p>.namespaces`).
     Introduce a new one only when no existing one applies.
   - `description` — what the string means **in context** (not just
     what it literally says).
   - `context` — when the same word can mean different things in
     different screens.
   - `placeholders` — every ICU placeholder, with a `type`
     (`String`, `int`, `double`, `DateTime`) and a short description.
4. Preserve every ICU placeholder name exactly. Don't rename
   `{userName}` to `{user_name}` — the placeholder name is part of
   the contract with the source code.
5. Preserve ICU plural / select structure exactly. If the source has
   `=N` cases, keep them; CLDR categories (`zero/one/two/few/many/other`)
   are filled in by translators per locale, not by you here.
6. Apply `glossary.yaml`. Use the appropriate inflection in the target
   language (e.g. "Book" the verb → Spanish "Reservar"; "Booking"
   the noun → "Reserva").

---

## 3. Where to write

- **Source strings (only)** → `dialect/source/{{SOURCE_LOCALE}}.arb`.
- **Translations** → `dialect/translations/<locale>.arb`, one file per
  target locale in `{{TARGET_LOCALES}}`. Translation files carry only
  `@@locale` and the translated key/value pairs — **no `@key` blocks**
  (the CLI strips them if you add them).
- Don't write anywhere else. Don't modify source code. Don't touch
  files outside `dialect/`.

You don't have to remember sort order or formatting — add entries in
any reasonable shape, then run `dialect check --fix` and the CLI
normalizes them.

---

## 4. Hard guardrails

You **must not**:

- Modify any source code file (`.dart`, `.kt`, `.swift`, `.cs`, `.tsx`,
  etc.). You may **read** them to derive descriptions; you may not
  edit them.
- Overwrite an existing key in `dialect/source/{{SOURCE_LOCALE}}.arb`.
  If you believe an existing key is wrong, leave it alone and add a
  note in the task summary you report back — the developer decides
  renames.
- Invent new `@key` metadata fields outside the convention.
- Translate the source locale itself.
- Delete keys you don't recognize.
- Add `@key` blocks to translation files.

---

## 5. Finalize (run these yourself)

You're driving the CLI from here. Run these in order from the project
root and only stop if one reports an error:

1. `dialect check --fix` — normalize formatting (sort keys, place
   `@key` blocks, strip translation-side metadata) and surface
   structural problems with file:line hints.
2. `dialect sync` — generate the platform-specific output files
   declared under `platforms:` in `dialect.yaml`. Idempotent;
   re-running with no changes touches nothing.
3. `dialect check` — confirm a clean pass after the sync.

Then report a brief summary: how many keys you added, which
namespaces you used, the platform files written, anything you
deliberately skipped, and anything that needs the developer's
attention. If `dialect check` shows warnings (not errors), leave
them for the developer to triage rather than guessing.

The deterministic CLI work — formatting, sync, validation — is yours
to run; the developer's job is review, not orchestration.
''';
// dart format on
