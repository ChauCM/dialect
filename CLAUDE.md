# CLAUDE.md

This file briefs Claude Code (and any other AI agent) on the Dialect project so you can pick up work without re-reading the entire repo.

> **Status:** v1.0 shipping. The convention is locked, the CLI is feature-complete, distribution is wired (Pub + Homebrew + curl + GitHub Action). Treat this as production code, not a greenfield project.

---

## 1. What Dialect is (in one paragraph)

Dialect is an **AI-native localization toolkit** for Flutter-led teams. It is a CLI (`dialect init`, `dialect sync`, `dialect check`, `dialect serve`, …), a convention (an opinionated way of organizing ARB files with rich metadata), and a small set of integration packages (`Dialect.AspNetCore` NuGet, `dialect_ota` Flutter package). The killer feature is **cross-platform sync from one canonical source**: a Flutter dev adds a key, runs one command, and iOS `.strings`, Android `strings.xml`, and the ASP.NET backend's JSON all update in every locale. It is positioned as a **Lokalise replacement for Flutter-led teams who code with AI** — not an all-in-one TMS.

---

## 2. Read these first (in this order)

| Order | Document | Why |
|---|---|---|
| 1 | [`README.md`](README.md) | Elevator pitch, two-step happy path, install + advanced surface. |
| 2 | [`docs/thesis.md`](docs/thesis.md) | The problem Dialect solves and why it solves it this way. |
| 3 | [`docs/architecture.md`](docs/architecture.md) | Convention (flat camelCase keys + `@key.namespace`), CLI reference, `dialect.yaml` shape, check rules, glossary, review UI. |
| 4 | [`docs/platforms-frontend.md`](docs/platforms-frontend.md) | Flutter (`gen-l10n`-compatible by design), iOS, Android adapter specifics. |
| 5 | [`docs/platforms-backend.md`](docs/platforms-backend.md) | Backend integration via lossless localizer libraries (no `.resx` adapter). |
| 6 | [`docs/ota.md`](docs/ota.md) | OTA protocol for v1.2+. |
| 7 | [`dialect/spec/icu-json.md`](dialect/spec/icu-json.md), [`flat-json.md`](dialect/spec/flat-json.md) | Versioned on-disk contracts that backend localizer libraries target. |

The brainstorm phase (April–May 2026) is archived at `/Users/chaucao/Documents/github/brainstorm/dialect`. That repo carries the historical planning docs, research, references, and spikes that shaped the design — read them when you need *why* context that isn't in the shipping docs. None of that lives in this repo.

---

## 3. Non-negotiable principles

These shaped every decision. Honor them or you'll drift the product.

### 3.1 Syntactic work in the CLI, semantic work via AI-pointer

- **Syntactic (Dialect itself):** format conversion, sorting, validation, file I/O. Deterministic operations.
- **Semantic (AI-pointer):** importing existing translations, backfilling `@description` from callsites, translating missing keys, renaming keys. Dialect writes a structured instruction file (`.dialect/init-plan.md`, `.dialect/import-plan.md`, `.dialect/describe-plan.md`) and the **user's** AI agent (Cursor / Claude Code / Cline / Copilot / etc.) executes it. Dialect does not call an LLM for these operations by default.

The convenience escape hatch is `dialect translate --auto --provider {anthropic|openai}` for CI use cases. Even there, the AI-pointer flow is the documented primary path.

**Why this matters:** model-agnostic, vendor-neutral, ages well as models change, keeps the codebase small.

### 3.2 Backend Humility

We do **not** ship lossy format adapters (`.resx`, `.po`) when a lossless localizer-library path exists. Dialect outputs JSON (`flat-json` or `icu-json`). Per-stack support is:

- **ASP.NET** — a real NuGet package `Dialect.AspNetCore` exposing `services.AddDialectLocalization("wwwroot/locales")`. Implements `IStringLocalizer<T>` over Dialect's `icu-json`. Callsites unchanged.
- **Django / Flask / FastAPI / Node / Go** — documented snippet (~10–15 lines), no Dialect-maintained package. Existing libraries (`i18next-fs-backend`, `go-i18n`) already consume Dialect's JSON natively.

A BE engineer adopting Dialect should never have to abandon their stack's localization interface.

### 3.3 Flutter Humility

The convention is **flat camelCase keys** (`checkoutBookNow`) with logical grouping in `@key.namespace` metadata. This is what `flutter gen-l10n` requires — every key in the source ARB becomes a method on `AppLocalizations` after sync. No mangling, no impedance mismatch with Flutter's default localization tool.

If a feature would require dotted keys or any non-`gen-l10n`-compatible shape, push back.

### 3.4 Lokalise-replacement-for-Flutter, not all-in-one TMS

Dialect is **focused**. The README's "Who Dialect is for" / "isn't for" sections explicitly say no to regulated industries needing audit trails, dedicated localization-ops teams, React-web-only teams, solo devs shipping one app in two languages, and shops that can't use AI tools.

If a feature request feels like "let's also do X for audience Y," check those sections first.

### 3.5 Stable JSON contract

`icu-json` and `flat-json` output shapes are versioned. Specs live at [`dialect/spec/icu-json.md`](dialect/spec/icu-json.md) and [`dialect/spec/flat-json.md`](dialect/spec/flat-json.md). Backend localizer libraries (NuGet, snippets) target this contract. Breaking changes require a major version bump.

---

## 4. Tech stack (locked)

| Component | Stack | Notes |
|---|---|---|
| CLI | **Dart** | `dart compile exe` → ~8 MB self-contained binary. Backend engineers never need the Dart SDK; they install pre-built binaries. |
| Review UI / dashboard | **Svelte 5** (runes) + Vite 8, pnpm-managed | Embedded as static assets in the CLI binary via `tool/build_dashboard.dart`. Served by a Dart Shelf server on `localhost:4077`. No `npm install` for end users. |
| OTA Flutter package (`dialect_ota`) | **Dart** | v1.3+. Thin wrapper around `http` + `shared_preferences` + custom `LocalizationsDelegate`. |
| ASP.NET integration | **C# (`net8.0`)** NuGet package `Dialect.AspNetCore` | v1.1. First-class real package. Other backend stacks stay as snippets. |
| LLM client (for `--auto` mode) | Hand-rolled HTTP over Anthropic / OpenAI REST | v1.2+. ~50 lines per provider. Don't depend on community SDKs. |

**Distribution channels (shipping from v1.0):** Pub + Homebrew tap (`ChauCM/homebrew-tap`) + curl install script + GitHub Action (`ChauCM/dialect@v1`). Docker + Scoop are deliberate cuts for v1.0 — revisit if requested.

---

## 5. The onboarding flow (the v1.0 happy path)

A user adopting Dialect in a Flutter project takes **one CLI command + one chat message**:

```bash
dialect init     # scaffolds dialect/, writes .dialect/init-plan.md + AGENTS.md
```

Then in their AI agent:

> run dialect init and follow the instructions

The AI:
1. Re-runs `dialect init` (idempotent — refreshes the plan).
2. Reads `.dialect/init-plan.md` — a two-phase playbook.
3. Executes **Phase 1**: adds `flutter_localizations`, creates `l10n.yaml`, wires `MaterialApp.localizationsDelegates`, adds a locale switcher, smoke-tests one key.
4. Executes **Phase 2** based on codebase size: ≤50 candidate strings → extract + translate in one turn; >50 → extract only, stop for the dev to review key names before the long translation step.

`AGENTS.md` at the project root teaches every future agent session about Dialect, so "add translation for the new screen" just works.

The chat-message default is **`run dialect init and follow the instructions`** — short enough to type without copy-paste.

---

## 6. Anti-goals (don't do these)

- **Don't ship a `.resx` adapter.** ASP.NET integration is the `Dialect.AspNetCore` NuGet package consuming `icu-json`. See Backend Humility (§3.2).
- **Don't ship a gettext `.po` adapter.** Same reasoning.
- **Don't have Dialect parse source code.** `dialect import` / `dialect describe` write instruction files for the user's AI. Dialect never opens `.dart`, `.kt`, `.swift`, `.cs` files itself.
- **Don't reintroduce dotted keys** (`checkout.bookNow`). They break `flutter gen-l10n`. Use flat camelCase + `@key.namespace` metadata.
- **Don't add a hosted dashboard or SSO to v1.** All of that is v2 business-layer work, gated on real user adoption.
- **Don't build a translator marketplace, human-review workflow, or approval chain.** Pin/lock is the v1 answer for "human-approved this translation."
- **Don't ship `dialect translate --auto` as the default `translate` behavior.** The AI-pointer flow is primary; `--auto` is a CI convenience.
- **Don't add telemetry, version-check pings, or any phone-home.** v1.0 anti-goal.
- **Don't add backwards-compat shims for the pre-1.0 dotted-key convention.** Pre-1.0 had no released users; no migration story needed.

---

## 7. Repo layout

```
dialect/
├── bin/                        # Dart CLI entry point
│   └── dialect.dart
├── lib/                        # Dart CLI source
│   ├── adapters/               # Per-platform format conversion (ARB v1.0)
│   ├── arb/                    # ARB parsing + serialization
│   ├── checks/                 # Structural + semantic check rules
│   ├── commands/               # One file per CLI subcommand
│   ├── server/                 # Dart Shelf server for `dialect serve`
│   └── templates/              # Generated Dart consts mirroring templates/
├── templates/                  # Canonical text of init scaffolding + plan files
├── dashboard/                  # Svelte SPA for `dialect serve`
├── dialect_aspnetcore/         # C# NuGet package (v1.1)
├── dialect_ota/                # Flutter OTA package (v1.3+)
├── dialect/spec/               # Stable JSON contract docs
│   ├── icu-json.md
│   ├── flat-json.md
│   ├── source_hash.md
│   └── state.md
├── test/                       # Dart tests
│   └── fixtures/canonical/     # Version-controlled Dialect project used by check/status/roundtrip tests
├── examples/                   # Two sister Flutter apps for demo + dialect CLI testing
│   ├── before/                 # Bare app, hardcoded English strings — the realistic starting point
│   ├── after/                  # Clone of before/, used as the test target for `dialect init`
│   └── _validation/            # Multi-model convention convergence harness (reads examples/before/lib/)
├── tool/                       # Build helpers (sync_templates, build_dashboard, …)
├── docs/                       # User-facing docs
├── .github/workflows/          # CI + release pipelines
├── homebrew/                   # Homebrew formula template
├── install.sh                  # POSIX installer
├── action.yml                  # GitHub composite action
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── pubspec.yaml
```

The `planning/`, `research/`, `references/`, and `spikes/` directories live in the brainstorm repo at `/Users/chaucao/Documents/github/brainstorm/dialect`, not here.

---

## 8. Dev workflow

| Task | Command |
|---|---|
| Install deps | `dart pub get` |
| Run the CLI from source | `dart run bin/dialect.dart <args>` |
| Run all tests | `dart test` |
| Run a single test file | `dart test test/path/to/foo_test.dart` |
| Run a single test by name | `dart test --name '<substring>'` |
| Format | `dart format .` |
| Static analysis | `dart analyze` |
| Build the release binary | `dart compile exe bin/dialect.dart -o build/dialect` (~8 MB) |
| Build the dashboard SPA | `cd dashboard && pnpm install && pnpm build` (Svelte + Vite) |
| Run the dashboard server in dev | `dart run bin/dialect.dart serve` (Dart Shelf on `localhost:4077`) |
| Regenerate `lib/templates/*.dart` from `templates/` | `dart run tool/sync_templates.dart` |
| Re-embed dashboard assets | `dart run tool/build_dashboard.dart` |

Per `CONTRIBUTING.md`: Dart code follows `dart format` defaults, keep functions small and testable, and prefer explicit types over `var` for public APIs.

The `Dialect.AspNetCore` NuGet package (v1.1) lives under `dialect_aspnetcore/` and is targeted at `net8.0`; it has its own `dotnet test` / `dotnet pack` lifecycle and is independent of the Dart build.

---

## 9. When to push back

If a future request would:

- Add a backend format adapter (`.resx`, `.po`, `.xliff`)
- Have Dialect parse source code directly
- Reintroduce dotted keys or any non-`gen-l10n`-compatible shape
- Make Dialect call an LLM as the default for semantic work
- Add enterprise TMS features in v1
- Target React-web-only / regulated industries / dedicated-loc-ops teams as primary
- Replace `IStringLocalizer<T>` with a Dialect-specific interface
- Add telemetry, version-check pings, or phone-home behavior

…push back and point at the relevant principle. These trade-offs were deliberate.

---

*Brainstorm authored by Chau Cao (April–May 2026). v1.0 implementation completed shortly after. The brainstorm docs are archived at `/Users/chaucao/Documents/github/brainstorm/dialect`.*
