// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/dialect.yaml`.

// dart format off
const String dialectYamlTemplate = r'''# ============================================================
# Dialect — Localization Convention
# ============================================================
# This file configures Dialect AND teaches AI assistants how
# to work with this project's translations.
#
# If you are an AI assistant: read this entire file before
# extracting or translating any strings. It is the spec.
#
# === The project ===
#   See the `project:` block at the bottom of this file.
#   Read it first — it tells you what the app does, which
#   disambiguates glossary terms (e.g. "Trip" = a booked
#   travel stay, not a corporate business trip).
#
# === Where strings live ===
#   - Canonical source strings live in dialect/source/en.arb
#     (and any other `dialect/source/<source_locale>.arb` if you
#     change `source_locale` below).
#   - Translated strings live in dialect/translations/<locale>.arb,
#     one file per target locale.
#   - The CLI syncs filtered output to each platform's directory
#     (e.g. Flutter's `lib/l10n/`) on `dialect sync`.
#
# === Key naming ===
#   - Keys are flat camelCase identifiers that are valid Dart
#     method names:
#       checkoutBookNow, commonCancel, settingsDarkMode
#     No dots, no dashes, no leading digit, no underscores in
#     normal use. This shape is required by Flutter's
#     `flutter gen-l10n` and matches Dart method-name rules,
#     so every key in en.arb becomes
#     `AppLocalizations.of(context)!.<key>` after sync.
#   - Logical grouping lives in metadata, NOT in the key:
#       "checkoutBookNow": "Book Now",
#       "@checkoutBookNow": {
#         "namespace": "checkout",
#         "description": "..."
#       }
#     The `namespace` controls which keys sync to which platform
#     (see `platforms.<p>.namespaces` below). Cross-platform
#     adapters use it to group output (e.g. one .strings file
#     per namespace on iOS).
#   - Two screens that currently render the same English string
#     get separate keys (e.g. `homeHostedBy` and
#     `checkoutHostedBy`). Identical-today is a coincidence,
#     not a guarantee. Only use the `common` namespace when a
#     key is *logically* shared (cancel / save / loading / delete).
#
# === After editing, normalize with the CLI ===
#   You do not need to remember sort order, formatting, or
#   indentation rules. Add or edit entries in any reasonable
#   shape, then run:
#       dialect check --fix     # normalizes + flags issues
#       dialect sync            # generates outputs, then reports
#                               # the state it left you in
#   Two commands, not three: `sync` ends by re-checking and
#   printing one line ("check: no issues." or a count), so the
#   confirming pass is already done. `dialect sync --verify` also
#   makes any remaining error the exit code, which is the whole
#   CI gate in one command.
#   `dialect check --fix` deterministically sorts keys, moves
#   `@@locale` to the top, places each `@key` block after its
#   own key, strips any `@key` blocks accidentally added to
#   translation files, and validates placeholder/plural shape.
#   It also warns (`output_drift`) when a generated file holds
#   keys the source does not — the one condition that makes the
#   `sync` in step two refuse — so step one tells you whether
#   this repo is in a state where sync can run.
#   Spend your effort on the SEMANTIC parts (good descriptions,
#   good translations, glossary application). The CLI handles
#   the rest.
#
#   If that warning fires on a project that used to add keys
#   straight to the generated files: that habit made sense when
#   `sync` deleted them, and `dialect sync --adopt` is the
#   one-time migration back. It recovers each key's English,
#   its `@key` metadata, and any translation that lived only in
#   the output, then regenerates.
#
# === Copy policy lives in glossary.yaml ===
#   `terms:` says what a translation must always say; `banned:`
#   says what no value may say (checked in the source too). Both
#   are warnings, so `dialect check --strict` is what makes them
#   a gate. See dialect/glossary.yaml.
#   `plural_shape` warns when a count is interpolated straight in
#   front of a plural noun ("{count} people" renders "1 people").
#   Wrap it in an ICU plural in the SOURCE — every translation
#   inherits the shape from there.
#
# === @key metadata (semantic part — your responsibility) ===
#   - Every key in the SOURCE ARB MUST have a "namespace" and a
#     "description" field in its matching `@key` entry.
#       "namespace": which group it belongs to (see platforms below).
#       "description": what the string means *in context*, not
#         just what it literally says.
#           Bad:   "description": "Book now button"
#           Good:  "description": "CTA on the checkout screen.
#                   'Book' is a verb meaning 'make a reservation',
#                   NOT a physical book."
#   - Add "context": "<screen_or_feature>" when the same word
#     might mean different things in different places.
#   - For strings with variables, add "placeholders" describing
#     each variable's type and meaning.
#   - Metadata lives only in the SOURCE ARB. Don't repeat it
#     in translation files; the CLI will strip it if you do.
#
# === Placeholders ===
#   - Use ICU MessageFormat for interpolation:  "Hello {userName}"
#   - Declare each placeholder in @key.placeholders with at
#     least a `type` (`String`, `int`, `double`, `DateTime`).
#   - Use the SAME placeholder name in every translation. Do
#     not translate the name itself. (`dialect check` will
#     catch mismatches.)
#
# === Slot budgets (size-aware translation) ===
#   Text expands when translated — "Edit profile" (12) becomes
#   Vietnamese "Chỉnh sửa trang cá nhân" (23) — and a faithful
#   but long value silently breaks a tight button or chip.
#   - If a string renders in a CONSTRAINED slot, say so on its
#     SOURCE `@key` block:
#       "@editProfile": { "x-slot": "button" }   # policy below
#       "@statusChip":  { "x-max-length": 10 }   # hard cap
#     Slot policies live once in the `slots:` block near the
#     bottom of this file (`max_ratio` = "stay within N× the
#     source"; `max_length` = an absolute character cap).
#   - This is OPT-IN. A key with neither field is never checked,
#     so body copy, legal text and empty-state prose keep all
#     the room they need. Only tag genuinely tight slots.
#   - Do NOT write the constraint as prose in `description`
#     ("must stay short", "sits in a 68px column"). A
#     description is a hope; a budget is a check. Prose there
#     cannot be enforced and cannot be handed to a translator.
#   - The payoff is up front, not after the fact: `dialect
#     translate` puts the resolved budget in the work list, so
#     the agent writes the short faithful form the first time —
#     shorten by WORD CHOICE (drop context-implied words: on a
#     profile header, "Edit profile" → "Edit"), never by
#     truncating mid-word or dropping a glossary term.
#   - `dialect check` also flags a source string that busts its
#     own budget — the slot is too tight even in English, which
#     no translation can fix. Widen the slot or shorten the
#     source. Warnings here are soft (`--strict-length` makes
#     them fail; they can be acked).
#
# === Plurals ===
#   - Use ICU plural select:
#       "{count, plural, =1{1 item} other{{count} items}}"
#   - Cover the CLDR plural categories required by the target
#     locale IN ADDITION TO any `=N` exact-match cases. The
#     two are independent: ICU evaluates `=N` first and falls
#     back to the matching CLDR category. You need BOTH —
#     not one or the other.
#     Common CLDR sets:
#       English:    one / other
#       German:     one / other
#       Spanish:    one / other
#       Arabic:     zero / one / two / few / many / other
#       Japanese:   other  (single-form)
#       Vietnamese: other  (single-form)
#   - Mirror any `=N` exact-match cases the source provides.
#     Don't synthesize extra `=N` cases the source doesn't have.
#   - Worked example. Source (English):
#       "{count, plural, =0{No items} =1{1 item} other{{count} items}}"
#     Correct Arabic translation:
#       "{count, plural,
#          =0{لا توجد عناصر} =1{عنصر واحد}
#          zero{لا توجد عناصر} one{عنصر واحد} two{عنصران}
#          few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}"
#     Notice: the `=0`/`=1` mirrors stay, AND all six CLDR
#     categories are present. Dropping the categories and
#     keeping only `=0`/`=1`/`other` is WRONG — counts of
#     2, 3, 4, 11, 100 etc. will fall to `other` instead of
#     the correct grammatical form.
#   - The CLI (`dialect check`) flags missing CLDR categories
#     as an error in `--strict`. Trust it; it will tell you
#     which category you missed.
#
# === Currency, units, dates, numbers ===
#   - Do not translate currency symbols, units, or numeric
#     values themselves.
#   - Match the position of the currency symbol used in the
#     source string. Per-locale repositioning of `$` is a
#     runtime number-formatting concern (use `intl`), not a
#     translation concern.
#
# === Glossary ===
#   - Before translating, read dialect/glossary.yaml.
#   - The `term` in the glossary is the canonical lemma (e.g.
#     "Book" as a verb). Use the appropriate inflection or
#     derivation in the target language — "Booking confirmed"
#     becomes Spanish `Reserva confirmada` (noun form), not
#     `Reservar confirmado` (mechanical verb substitution).
#     The `meaning` field tells you which sense applies.
#   - If a glossary term appears in a non-literal sense in a
#     specific key (e.g. "Book club" meaning a physical book),
#     mark the SOURCE key with the term waived in its `@key`
#     block, and leave a brief note in the description:
#       "@bookClub": { "glossary_exempt": ["Book"] }
#     Name the terms. `"glossary_exempt": true` also works but
#     waives EVERY term on that key — including ones the string
#     should still honor — and a diff showing `true` tells a
#     reviewer nothing about what was actually waived. One
#     string may need two terms waived for two different and
#     both-correct reasons; list them.
#
# === What NOT to extract ===
#   The following are NOT user-facing copy and should remain
#   hardcoded in source. Do not add them to ARB files.
#     - Personal names (e.g. "Linh Nguyen" sample profile data)
#     - Email addresses, phone numbers, URLs
#     - Currency amounts ("82", "$246") — these are data,
#       passed in as placeholders
#     - Dates and times — formatted at runtime with `intl`
#     - Language self-names in a language picker
#       (the Spanish UI still says "Español" in its picker, so
#       these names live in a per-locale data table, not in
#       translation files)
#     - Brand/product names you would not translate verbally
#     - Demo or placeholder content that exists only to make
#       the app look populated (sample listings, lorem ipsum)
#     - LONG-FORM DOCUMENTS: privacy policies, terms of service,
#       community guidelines, licences, changelogs. A document is
#       a document, not a string catalogue. Shredding one into
#       keys gives you meaningless key names, unreadable diffs,
#       and clauses that drift apart between locales — and in a
#       legal document a drifted clause is worse than no
#       translation at all. Keep them as per-locale files
#       (Markdown, MDX, one template per language), translate them
#       as documents, and state on the page which language
#       governs. Extract the CHROME around a document (nav labels,
#       an "available in English only" notice); leave the body of
#       it alone.
#   If in doubt: ask whether the string would change for a
#   different user. If yes, it's data, not copy. Then ask whether
#   it is a sentence in a UI or a section of a document. If it's a
#   document, it doesn't belong here either.
#
# === Workflow you should follow ===
#   1. Read dialect/dialect.yaml (this file) and dialect/glossary.yaml.
#   2. Read dialect/source/en.arb to see what keys already exist
#      and the style/length of existing descriptions.
#   3. For extraction tasks: find user-facing strings in the
#      source code that are not in the "What NOT to extract"
#      list. For each, propose a flat camelCase key, assign a
#      `namespace`, and add the key + `@key` block to
#      dialect/source/en.arb. Replace the hardcoded string in
#      source code with `AppLocalizations.of(context)!.<key>`
#      (Flutter) or the platform's equivalent. Do NOT overwrite
#      keys that already exist — they are the product of
#      earlier decisions.
#   4. For translation tasks: for every key in dialect/source/en.arb,
#      ensure a corresponding entry exists in each
#      dialect/translations/<locale>.arb. Keep the same key name;
#      translate only the value. Preserve placeholders and ICU
#      plural structure exactly. Respect the glossary.
#      Tip: `dialect translate` writes `.dialect/translate-plan.md` with
#      a per-locale work list of exactly which keys are missing (and
#      which locked translations went stale) — execute that plan.
#   5. Run `dialect check --fix && dialect sync && dialect check`
#      to normalize, generate platform output, and validate.
#
# === Things you must NOT do ===
#   - Do not rename existing keys without being asked.
#   - Do not change source code to reference keys that don't exist.
#   - Do not invent new @key fields outside this convention.
#   - Do not translate the source locale itself.
#   - Do not delete keys you don't recognize.
#   - Do not mirror @key metadata into translation ARB files.
#   - Do not use dotted keys (`checkout.bookNow`). They break
#     `flutter gen-l10n`. Use `@key.namespace` metadata instead.
#
# ============================================================


project:
  name: "Your project"
  description: >
    One-line description of what your app does. Translators
    and AI assistants read this to disambiguate glossary terms.

# The oldest Dialect the conventions in this file rely on. `dialect init`
# stamps the version it ran as; `dialect check` fails when the binary on
# PATH is older, because a stale binary can silently do the wrong thing
# (pre-1.2 `sync` deleted keys that lived only in generated output). Raise
# this when you adopt a feature that needs a newer release — that is the
# one line that makes the requirement enforceable instead of folklore.
# Pre-release suffixes are ignored: 1.2.0-dev satisfies `1.2.0`.
toolchain:
  min_version: {{DIALECT_VERSION}}

source_locale: en
target_locales: []  # add the locales you ship in, e.g. [es, fr, ja]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common]  # add more as your project grows

  # Cross-stack sync: emit the SAME source to a backend service, in JSON.
  # Uncomment and adjust to keep your Flutter app and backend in sync from
  # one canonical source. Two formats:
  #   icu-json  — preserves ICU plurals/select (backend has an ICU runtime)
  #   flat-json — collapses plurals to the `other` branch (no ICU runtime)
  # Only keys whose @key.namespace is listed here sync to this platform.
  # backend:
  #   output: api/locales/
  #   format: icu-json
  #   namespaces: [common, backend]

# Per-locale overrides for the length-ratio check.
# Each value is the [min, max] multiplier of source character length.
# Default for locales not listed: [0.3, 2.5].
length_ratio: {}

# Size-aware translation: budgets for tight, fixed-width UI slots.
# A key OPTS IN by tagging its SOURCE @key block with `x-slot: <name>` (a
# preset below) or a hard `x-max-length: <n>`. Keys with neither are never
# checked — body copy and anything that auto-sizes keeps all its room.
#   max_ratio  — stay within N× the source ("similar length"), floored at
#                source+grace so short labels never false-trip.
#   max_length — an absolute character cap (a real pixel-bounded slot).
#   grace      — optional; extra characters a ratio always allows (default 4).
# Soft by design: plain --strict leaves these warnings; --strict-length makes
# them fail. The real payoff is `dialect translate`, which hands the budget to
# the agent so the short faithful form is written up front.
# See the "Slot budgets" section in the header above.
slots: {}
# slots:
#   button: { max_ratio: 1.4 }   # "Edit profile" → "Chỉnh sửa", not the literal
#   chip:   { max_length: 10 }
#   tab:    { max_ratio: 1.2, grace: 2 }

# Publish immutable translation bundles for a backend to consume (v1.2).
# `dialect publish <env>` builds a content-hashed bundle and uploads it;
# `dialect pull <env>` fetches it (verifying integrity) in a deploy script.
# `target: local` writes to the filesystem; `s3` (R2/MinIO/AWS) is coming.
# publish:
#   staging:
#     target: local
#     path: dist/locales/staging/   # where the bundle is written
#     format: icu-json              # or flat-json
#     namespaces: [common, backend]
#     output: api/locales/          # where `dialect pull` writes the files
''';
// dart format on
