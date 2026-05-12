# Changelog

All notable changes to the Dialect CLI are tracked here. Pre-1.0 entries are
work-in-progress milestones from `planning/mvp-plan.md`.

## [Unreleased]

### Added
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
