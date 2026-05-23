# Dialect

**AI-native localization for Flutter-led teams.** One canonical source, synced across Flutter, iOS, Android, and your backend — driven by your existing AI editor (Claude Code, Cursor, Copilot, Cline…).

```
$ dialect init
$ dialect import --from arb --path lib/l10n/   # writes a plan; your AI executes it
$ dialect sync                                  # → iOS .strings, Android XML, backend JSON
$ dialect check                                 # structural + semantic validation
$ dialect serve                                 # localhost dashboard for review
```

[![CI](https://github.com/chaucao/dialect/actions/workflows/ci.yml/badge.svg)](https://github.com/chaucao/dialect/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

> **Status:** v1.0 code-complete; distribution channels (Homebrew, Scoop, Pub, Docker, GitHub Action) land with the v1.0.0 tag. Build from source today.

---

## Install

Today (until v1.0.0 ships on package managers):

```bash
git clone https://github.com/chaucao/dialect
cd dialect
dart compile exe bin/dialect.dart -o ~/.local/bin/dialect
dialect --version
```

Coming with v1.0.0:

```bash
brew install chaucao/tap/dialect       # macOS / Linux
scoop install chaucao/dialect          # Windows
dart pub global activate dialect       # any platform with Dart
curl -fsSL https://dialect.dev/install.sh | sh
```

## Quick start

```bash
cd your-flutter-project
dialect init                                              # scaffold dialect/
$EDITOR dialect/dialect.yaml                              # set target_locales: [es, ja, ar]
dialect import --from arb --path lib/l10n/                # writes .dialect/import-plan.md
# → open Claude Code / Cursor and say "follow .dialect/import-plan.md"
dialect check                                             # validate
dialect sync                                              # generate platform files
dialect serve                                             # localhost:4077 review UI
```

`dialect.yaml` carries inline convention comments that teach any AI assistant the rules — no plugin, no editor integration required.

## Features

- **One source of truth.** Canonical ARB in `dialect/source/<locale>.arb` syncs to Flutter, iOS `.strings`, Android `strings.xml`, and backend JSON.
- **AI-pointer flow.** `dialect import` / `describe` / `translate` write structured Markdown plans your existing AI agent executes. Vendor-neutral and ages with the models.
- **Real semantic checks.** Beyond placeholder/plural validation: source-equality, length-ratio (per-locale tunable), untranslated-English, glossary enforcement with `@key.glossary_exempt` escape hatch.
- **Local review UI.** `dialect serve` ships a Svelte SPA embedded in the binary — inline editing, lock-to-protect, glossary highlighting, coverage footer. Zero `node_modules` at runtime.
- **Backend Humility.** ASP.NET keeps `IStringLocalizer<T>`; Node/Python/Go keep their existing JSON loaders. Versioned [`icu-json`](dialect/spec/icu-json.md) / [`flat-json`](dialect/spec/flat-json.md) contracts are stable across major versions.
- **No phone-home, no telemetry, no SaaS.** Runs fully offline.

## Commands

| Command | Description |
|---|---|
| `dialect init` | Scaffold the `dialect/` directory |
| `dialect import` | Write an AI-pointer plan that imports existing translations into the convention |
| `dialect describe` | Write an AI-pointer plan that backfills `@description` from callsites |
| `dialect sync` | Generate platform-specific files from the canonical ARB |
| `dialect check` | Structural + semantic validation. `--strict` for CI; `--fix` to auto-normalize |
| `dialect status` | Per-locale coverage / stale / missing / locked |
| `dialect serve` | Local web UI for review and inline editing |

Planned for v1.2: `dialect translate` (AI-pointer + `--auto` for direct LLM call), `dialect publish` (OTA), `dialect merge` (key-aware git merge driver).

## Documentation

| Doc | What it covers |
|---|---|
| [Why Dialect](docs/thesis.md) | The localization-sync problem and the design insight |
| [Architecture](docs/architecture.md) | File convention, CLI reference, `dialect.yaml`, REST API |
| [Mobile platforms](docs/platforms-frontend.md) | Flutter, iOS, Android adapter specifics |
| [Backend platforms](docs/platforms-backend.md) | ASP.NET, Node, Python, Go integration patterns |
| [OTA updates](docs/ota.md) | Over-the-air protocol and the `dialect_ota` Flutter package |

### Stable on-disk contracts

| Spec | Description |
|---|---|
| [`icu-json`](dialect/spec/icu-json.md) | Backend JSON that preserves ICU plural/select byte-identically |
| [`flat-json`](dialect/spec/flat-json.md) | Backend JSON with plural/select flattened to plain strings |
| [`@key.source_hash`](dialect/spec/source_hash.md) | Source-value fingerprint that powers `status` "stale" and dashboard lock |
| [`.dialect/state.json`](dialect/spec/state.md) | Soft-mode acknowledgement store for `dialect check` |

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Pre-1.0 the SDK floor tracks current stable Dart; tests use `dart test`, format is `dart format` defaults, analysis is `dart analyze --fatal-infos --fatal-warnings`.

## License

[MIT](LICENSE.md)
