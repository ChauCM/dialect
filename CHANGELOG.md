# Changelog

All notable changes to the Dialect CLI are tracked here. Pre-1.0 entries are
work-in-progress milestones from `planning/mvp-plan.md`.

## [Unreleased]

### Changed
- **M2 hardening.** Pre-emptive fixes to the ARB substrate before M3 builds
  on it.
  - Parser preserves unknown `@@<name>` file-level metadata in
    `ArbFile.fileMetadata` (e.g. Flutter `gen_l10n`'s `@@last_modified`).
    Writer emits it after `@@locale` in sorted order. Prevents silent
    data loss on `dialect sync`.
  - Orphan `@key` blocks (no matching key/value) preserved in
    `ArbFile.orphanMetadata` so M4 can surface them as structural errors
    without re-reading raw JSON. Writer skips orphans by construction —
    `dialect check --fix` strips them implicitly.
  - `example/dialect/source/en.arb` synced with the canonical 30-key
    extract from `_validation/runs/claude-post-patch/`. Matches the
    translation files now.
  - `arb_roundtrip_test.dart` resolves the seed via `test/_support/repo_root.dart`
    instead of a `cwd`-relative path.
  - Removed unused `intl: ^0.20.2` dependency.
- **Tooling.** `tool/sync_version.dart` keeps `lib/version.dart` in lock-
  step with `pubspec.yaml`'s `version:` field. `--check` mode runs in CI
  so a forgotten sync fails the build. Stricter hand-picked lints
  (`unawaited_futures`, `avoid_dynamic_calls`, `prefer_relative_imports`,
  `directives_ordering`, `prefer_final_locals`, `cancel_subscriptions`,
  `close_sinks`) layered on top of `package:lints/recommended.yaml`.
- **CI.** `.github/workflows/ci.yml` runs `dart pub get`, version-sync
  `--check`, `dart format --set-exit-if-changed`, `dart analyze
  --fatal-infos --fatal-warnings`, and `dart test` on every push and PR.
- **Docs.** `planning/mvp-plan.md` updated to reflect that
  `intl_translation` is deprecated and Dialect ships a focused ICU
  scanner; future agents reading the plan won't try to "fix" the code
  by ripping out the scanner.

### Added
- **M2.** ARB read/write + ICU detection (`lib/arb/`).
  - `arb_file.dart`: typed model with `description`, `context`, `placeholders`,
    `locked`, `glossary_exempt`, `source_hash`, plus extras pass-through.
  - `arb_parser.dart`: reads ARB JSON; NFC-normalizes all string values
    (`unorm_dart`) so Vietnamese NFD vs NFC inputs hash identically.
  - `arb_writer.dart`: emits canonical ARB JSON matching the seed file
    byte-for-byte (sorted keys, `@@locale` first, `@key` after its key,
    blank-line separators).
  - `icu_message.dart`: focused scanner exposing
    `extractPlaceholders`, `extractPluralCategories`, `hasExpressions`.
    Handles `''` and `'…'` ICU escape, nested plural/select branches,
    selectordinal, and the Round-2 "=N mirrors AND CLDR categories"
    pattern. 40 tests including byte-identical round-trip on the seed.
- **M1.** Dart CLI scaffold: `dart create --template=cli` baseline, `pubspec.yaml`
  with SDK constraint `^3.4.0`, `args ^2.7.0` and `lints ^6.0.0` dev. Entry point
  at `bin/dialect.dart`. `DialectCommandRunner` wires the seven v1.0 commands
  (`init`, `import`, `describe`, `sync`, `check`, `status`, `serve`) as stubs.
  `--version` and `--help` work. Anti-goal PR checklist in
  `.github/PULL_REQUEST_TEMPLATE.md`.
- **M0+.** Multi-model convention convergence test across five models (Claude
  Opus, Claude Sonnet 4.6, Composer 2.5, Gemini 3.5 Flash, Codex 5.3). 9 of 10
  axes converged. One Round 2 patch (Arabic CLDR plural worked example).
  See `example/_validation/COMPARISON.md`.
- **M0.** Canonical convention text in `example/dialect/dialect.yaml`,
  `glossary.yaml`, and seed `source/en.arb`. Sample booking-style Flutter app
  under `example/lib/`. Validation report in
  `planning/convention-validation-report.md`.
