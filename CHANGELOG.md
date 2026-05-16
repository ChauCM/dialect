# Changelog

All notable changes to the Dialect CLI are tracked here. Pre-1.0 entries are
work-in-progress milestones from `planning/mvp-plan.md`.

## [Unreleased]

### Changed
- **M3 follow-up.** Three small fixes before M4 starts.
  - `templates/glossary.yaml` now ships with one example term + a
    "Replace or delete this entry" hint, the same pedagogical role as
    `common.example` in `source/en.arb`. Was effectively empty before.
  - SDK floor bumped from `^3.4.0` to `^3.11.0` (current stable Dart).
    Pre-1.0 policy: track current stable. Locks at "current + previous
    two minor SDK versions" at 1.0 launch. Policy documented in
    `planning/mvp-plan.md`.
  - `tool/sync_templates.dart` simplified — the `dart format` pipe
    workaround removed in favour of `// dart format off` directives in
    the generated source. The directive landed in Dart 3.7 and is now
    honored on every supported SDK.
- **v1.0.1 backlog** (flagged from M3 review, intentionally not blocking
  M4):
  - `dialect init --force` is whole-tree overwrite for the canonical
    files. A separate `--refresh` (write only missing files) is
    friendlier for users with customized `dialect.yaml`.
  - `project.name` could auto-detect from a sibling `pubspec.yaml`'s
    `name:` field, falling back to the directory basename. Currently
    everyone gets the placeholder "Your project".

### Added
- **M3.** `dialect init` — the first user-facing command.
  - Accepts an optional positional `[path]` argument (defaults to cwd).
  - `--force` overwrites an existing `dialect/` directory.
  - Writes `dialect/dialect.yaml`, `dialect/glossary.yaml`,
    `dialect/source/en.arb`; creates `dialect/translations/`.
  - Appends `.dialect/` to `.gitignore` (creates the file if missing,
    deduplicates if already present).
  - Exit codes: 0 success, 64 usage, 65 dialect/ exists w/o `--force`,
    66 target directory missing.
- **Templates pipeline.** Canonical seed YAML/ARB at repo-root
  `templates/`; `tool/sync_templates.dart` bakes them into Dart
  constants under `lib/templates/*.dart`. `--check` mode wired into CI
  so a hand-edited generated file fails the build. The generator pipes
  output through in-project `dart format` so the on-disk shape always
  matches what `dart format` would produce. 9 init tests in
  `test/commands/init_test.dart` (creation, byte-identical templates,
  .gitignore handling, --force, error cases).

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
