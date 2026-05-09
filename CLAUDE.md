# CLAUDE.md

This file briefs Claude Code (and any other AI agent) on the Dialect project so you can pick up implementation from the brainstorm phase.

> **Status:** Brainstorm phase complete (April–May 2026). Architecture, MVP plan, competitive strategy, and tech stack are locked in. **Implementation has not started yet.** Your job is to begin building v1.0.

---

## 1. What Dialect is (in one paragraph)

Dialect is an **AI-native localization toolkit** for Flutter-led teams. It is a CLI (`dialect sync`, `dialect check`, `dialect serve`, …), a convention (an opinionated way of organizing ARB files with rich metadata), and a small set of integration packages (`Dialect.AspNetCore` NuGet, `dialect_ota` Flutter package). The killer feature is **cross-platform sync from one canonical source**: a Flutter dev adds a key, runs one command, and iOS `.strings`, Android `strings.xml`, and the ASP.NET backend's JSON all update in every locale. It is positioned as a **Lokalise replacement for Flutter-led teams who code with AI** — not an all-in-one TMS.

---

## 2. Read these first (in this order)

The brainstorm is the source of truth. Don't make architectural decisions without consulting it.

| Order | Document | Why |
|---|---|---|
| 1 | [`README.md`](README.md) | Elevator pitch, who Dialect is/isn't for, command status table. |
| 2 | [`docs/thesis.md`](docs/thesis.md) | The problem Dialect solves and why it solves it this way. |
| 3 | [`planning/competitive-strategy.md`](planning/competitive-strategy.md) | **Backend Humility** principle, target audience, what we deliberately don't do. |
| 4 | [`planning/mvp-plan.md`](planning/mvp-plan.md) | v1.0 / v1.1 / v1.2 scope, tech stack, distribution plan, what external reviews flagged. |
| 5 | [`docs/architecture.md`](docs/architecture.md) | File convention, CLI reference, `dialect.yaml` shape, check rules, glossary, review UI. |
| 6 | [`docs/platforms-frontend.md`](docs/platforms-frontend.md) | ARB / iOS / Android adapter specifics. |
| 7 | [`docs/platforms-backend.md`](docs/platforms-backend.md) | Backend integration via lossless localizer libraries (no `.resx` adapter). |
| 8 | [`docs/ota.md`](docs/ota.md) | OTA protocol for v1.2+. |

Everything in `research/` is AI-generated competitive analysis — read if you want context on a specific competitor, otherwise skip.

---

## 3. Non-negotiable principles

These shaped every decision in the brainstorm. Honor them or you'll drift the product.

### 3.1 Syntactic work in the CLI, semantic work via AI-pointer

- **Syntactic (Dialect itself):** format conversion, sorting, validation, file I/O. Deterministic operations.
- **Semantic (AI-pointer):** importing existing translations, backfilling `@description` from callsites, translating missing keys, renaming keys. Dialect writes a structured instruction file (`.dialect/import-plan.md`, `.dialect/describe-plan.md`, `.dialect/translate-plan.md`) and the **user's** AI agent (Cursor / Claude Code / Cline / Copilot / etc.) executes it. Dialect does not call an LLM for these operations by default.

The convenience escape hatch is `dialect translate --auto --provider {anthropic|openai}` for CI use cases. Even there, the AI-pointer flow is the documented primary path.

**Why this matters:** model-agnostic, vendor-neutral, ages well as models change, keeps the codebase small.

### 3.2 Backend Humility

We do **not** ship lossy format adapters (`.resx`, `.po`) when a lossless localizer-library path exists. Dialect outputs JSON (`flat-json` or `icu-json`). Per-stack support is:

- **ASP.NET** — a real NuGet package `Dialect.AspNetCore` exposing `services.AddDialectLocalization("wwwroot/locales")`. Implements `IStringLocalizer<T>` over Dialect's `icu-json`. Callsites unchanged.
- **Django / Flask / FastAPI / Node / Go** — documented snippet (~10–15 lines), no Dialect-maintained package. Existing libraries (`i18next-fs-backend`, `go-i18n`) already consume Dialect's JSON natively.

A BE engineer adopting Dialect should never have to abandon their stack's localization interface. They keep `IStringLocalizer<T>` / `_()` / `i18n.Localize()` exactly as-is; only the backing store swaps.

### 3.3 Lokalise-replacement-for-Flutter, not all-in-one TMS

Dialect is **focused**. The README's "Should you use Dialect?" section explicitly says no to:
- Regulated industries needing audit trails (use a real TMS)
- Dedicated localization-ops teams (use Lokalise / Crowdin)
- React-web-only teams (i18next already solves it)
- Solo devs shipping one app in two languages (overkill)
- Shops that can't use AI tools (the value proposition collapses)

If a feature request feels like "let's also do X for audience Y," check this section before agreeing.

### 3.4 Stable JSON contract

`icu-json` and `flat-json` output shapes are versioned (spec docs live at `dialect/spec/icu-json.md` and `dialect/spec/flat-json.md` — to be written in v1.0). Backend localizer libraries (NuGet, snippets) target this contract. Breaking changes require a major version bump.

---

## 4. Tech stack (locked)

| Component | Stack | Notes |
|---|---|---|
| CLI | **Dart** | `dart compile exe` → ~7 MB self-contained binary. Backend engineers never need the Dart SDK; they install pre-built binaries. |
| Review UI / dashboard | **Svelte** (built with Vite) | Embedded as static assets in the CLI binary. Served by a Dart Shelf server on `localhost:4077`. No `npm install` for end users. |
| OTA Flutter package (`dialect_ota`) | **Dart** | Thin wrapper around `http` + `shared_preferences` + custom `LocalizationsDelegate`. |
| ASP.NET integration | **C# (`net8.0`)** NuGet package `Dialect.AspNetCore` | First-class real package, not a copy-paste snippet. Other backend stacks stay as snippets. |
| LLM client (for `--auto` mode) | Hand-rolled HTTP over Anthropic / OpenAI REST | ~50 lines per provider. Don't depend on community SDKs. |
| Future CLI escape hatch | **Go** (not Rust) | Only if Dialect grows beyond the Flutter audience and the Dart-binary "Flutter-tool" signal becomes a barrier. |

**Distribution from v1.0 launch:** Pub + Homebrew tap + Scoop manifest + curl install script + Docker image + GitHub Action. Backend engineers install the binary like `gh` or `kubectl` — they never see the Dart toolchain.

---

## 5. v1.0 scope (build in this order)

The full v1.0 list is in [`planning/mvp-plan.md`](planning/mvp-plan.md). Suggested implementation order:

1. **The convention without code.** Hand-author `dialect.yaml` and `glossary.yaml` example files. Drop them into a small sample Flutter app with 2–3 screens. Point a stock AI agent (Claude Code / Cursor) at `dialect.yaml` and ask it to extract strings + translate. **If the agent reliably produces correct ARB without further help, the convention is right.** This is the cheapest validation — do it before writing CLI code.
2. **Dart CLI scaffold.** `pub init`, `bin/dialect.dart` entry point, basic command routing (`args` package). Wire up `dialect --version` and `dialect --help`.
3. **`dialect init`** — pure file generation. Scaffold the `dialect/` directory with the convention-documented `dialect.yaml` from step 1.
4. **`dialect check` (structural)** — ARB parser, key existence check, placeholder match, plural-category validation.
5. **`dialect sync` (ARB-to-ARB)** — trivial for v1.0 (copy with key sorting + namespace filtering). The interesting adapters are v1.1.
6. **`dialect status`** — coverage table output.
7. **`dialect import`** — write `.dialect/import-plan.md` template. No code parsing in Dialect itself.
8. **`dialect describe`** — write `.dialect/describe-plan.md` template.
9. **`dialect check` (semantic heuristics)** — source-equality, length-ratio (per-locale configurable), untranslated-English-fragment regex, **glossary enforcement with `@key.glossary_exempt` escape hatch**.
10. **Spec docs** — write `dialect/spec/icu-json.md` and `dialect/spec/flat-json.md` documenting the versioned JSON contract.
11. **Dashboard (`dialect serve`)** — Dart Shelf server + Svelte SPA. Embed compiled SPA assets in the Dart binary. REST API per `docs/architecture.md`. Pin/lock + inline editing. This is the visual "wow" for the launch demo.
12. **Distribution pipeline** — GitHub Actions to build binaries for macOS x64/arm64, Linux x64/arm64, Windows x64 on every release tag. Publish to Pub. Set up Homebrew tap, Scoop manifest, install.sh, Docker image, GitHub Action.
13. **2-minute demo video.** Record `dialect init` → AI extracts strings → `dialect sync` → `dialect check` → open dashboard. Post to Flutter Reddit / Twitter / dev.to.

Don't move to v1.1 (iOS/Android/backend adapters + `Dialect.AspNetCore` NuGet) until v1.0 has real user signal.

---

## 6. Anti-goals (don't do these)

- **Don't ship a `.resx` adapter.** ASP.NET integration is the `Dialect.AspNetCore` NuGet package consuming `icu-json`. See [Backend Humility](planning/competitive-strategy.md#backend-humility).
- **Don't ship a gettext `.po` adapter.** Same reasoning.
- **Don't have Dialect parse source code.** `dialect import` / `dialect describe` write instruction files for the user's AI. Dialect never opens `.dart`, `.kt`, `.swift`, `.cs` files itself.
- **Don't add a hosted dashboard or SSO to v1.** All of that is v2 business-layer work, gated on real user adoption.
- **Don't build a translator marketplace, human-review workflow, or approval chain.** Pin/lock is the v1 answer for "human-approved this translation."
- **Don't ship `dialect translate --auto` as the default `translate` behavior.** The AI-pointer flow is primary; `--auto` is a CI convenience.
- **Don't optimize for non-Flutter audiences in v1.** Flutter-first. If the Dart binary feels foreign to Node/Python BE devs later, the v2+ Go rewrite is the escape hatch.
- **Don't add features without checking the "Who Dialect is NOT for" list** in `README.md`.

---

## 7. Repo layout (to be created during implementation)

You'll add these as you build:

```
dialect/
├── bin/                        # Dart CLI entry point
│   └── dialect.dart
├── lib/                        # Dart CLI source
│   ├── commands/
│   │   ├── init.dart
│   │   ├── check.dart
│   │   ├── sync.dart
│   │   ├── status.dart
│   │   ├── import.dart
│   │   ├── describe.dart
│   │   └── serve.dart
│   ├── arb/                    # ARB parsing + serialization
│   ├── adapters/               # Per-platform format conversion
│   ├── checks/                 # Structural + semantic check rules
│   └── server/                 # Dart Shelf server for dialect serve
├── dashboard/                  # Svelte SPA for dialect serve
│   ├── src/
│   ├── package.json
│   └── vite.config.ts
├── dialect_aspnetcore/         # C# NuGet package (v1.1)
├── dialect_ota/                # Flutter OTA package (v1.3)
├── spec/                       # Stable JSON contract docs
│   ├── icu-json.md
│   └── flat-json.md
├── test/                       # Dart tests
├── example/                    # Sample Flutter app for the demo
├── pubspec.yaml
├── README.md                   # Already written
├── docs/                       # Brainstorm docs (already written)
├── planning/                   # Brainstorm docs (already written)
└── ...
```

The `docs/`, `planning/`, `research/`, `references/`, and `spikes/` folders carry over from the brainstorm and stay as-is. Treat them as read-only context, not files to edit during implementation (except to update status lines or correct genuine errors).

---

## 8. Kickoff prompt (copy-pasteable)

If you're a fresh agent landing in this repo, here's the prompt to start with:

> I'm picking up implementation of Dialect, an AI-native localization toolkit for Flutter-led teams. The brainstorm phase is complete — read `CLAUDE.md` first for context and principles, then `README.md`, `planning/mvp-plan.md`, and `docs/architecture.md`. Build order for v1.0 is in CLAUDE.md §5. Start with step 1: hand-author a `dialect.yaml` and `glossary.yaml` example, drop them in a minimal sample Flutter app under `example/`, and test whether a stock AI agent can correctly extract and translate strings using only those files as context. Report what works and what needs to be sharpened in the convention before we write any CLI code.

---

## 9. When to push back

The brainstorm reflects a series of deliberate trade-offs. If a future request would:

- Add a backend format adapter (`.resx`, `.po`, `.xliff`)
- Have Dialect parse source code directly
- Make Dialect call an LLM as the default for semantic work
- Add enterprise TMS features in v1
- Target React-web-only teams as primary
- Replace `IStringLocalizer<T>` with a Dialect-specific interface

…push back and point at the relevant brainstorm section. The user has thought through these and chosen not to do them.

---

*Brainstorm authored by Chau Cao (April–May 2026). This file is the bridge from brainstorm to implementation.*
