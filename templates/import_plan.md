# Dialect import plan

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
2. Rename the key to `namespace.camelCaseKey`. Pick an existing
   namespace when it fits (see `Current namespaces` above and
   `platforms.<p>.namespaces` in `dialect.yaml`). Introduce a new
   namespace only when no existing one applies — the developer will
   add it to `platforms.<p>.namespaces` before the next sync.
3. Add full `@key` metadata to the SOURCE ARB:
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

## 5. When you're done

1. Run `dialect check --fix` from the project root. It will normalize
   formatting and flag any structural problems with file:line hints.
2. Fix anything `dialect check` reports as an error. Warnings are
   fine to leave for the developer to triage.
3. Report a brief summary: how many keys you added, which namespaces
   you used, anything you deliberately skipped, anything you flagged
   for the developer's attention.

Do **not** run `dialect translate` or `dialect sync` — those are the
developer's calls.
