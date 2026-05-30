# CLAUDE.md

This file briefs Claude Code (and any other AI agent) on the Dialect project so you can pick up work without re-reading the entire repo.

> **Status:** v1.0 shipping locally; v1.1 → v1.3 plan reshaped 2026-05-25. The CLI + convention + distribution are production. The current direction (per `docs/roadmap.md`):
> - **v1.1** — Backend sync lands (`icu-json`, `flat-json` adapters), `dialect serve` auto-resyncs, sync CLI ergonomics (`--dry-run`, `--platform`, `--watch`). **iOS/Android native adapters dropped from the roadmap** — Flutter handles those via its own build; document the gap. See `docs/roadmap.md`.
> - **v1.2** — Bundle format spec + `dialect publish` / `dialect pull` to user-managed buckets (S3 / R2 / git / local). Backends read bundle URLs at startup via a documented snippet (the nice-to-have `Dialect.AspNetCore` package would add a typed option). **No background poller** — `dialect pull` + redeploy is the live-update mechanism.
> - **v1.3** — **Dialect Cloud MVP** at dialect.tools. Cloud-first; self-host is a deliberate second-class port that ships in v1.4. See `docs/cloud.md` for the public framing.

---

## 1. What Dialect is (in one paragraph)

Dialect is an **AI-native localization toolkit** for Flutter-led teams. It is a CLI (`dialect init`, `dialect sync`, `dialect check`, `dialect serve`, …), a convention (an opinionated way of organizing ARB files with rich metadata), and a small set of integration docs/packages (documented backend snippets including an ASP.NET `JsonStringLocalizer`; a `Dialect.AspNetCore` NuGet is a planned nice-to-have, not release-blocking; `dialect-server` + Cloud at dialect.tools in v1.3). The killer feature is **cross-stack sync from one canonical source**: a Flutter dev (with their AI agent) adds a key, the AI generates translations in the same turn, and one command syncs both the Flutter app's ARBs and the backend's JSON across every locale. It is positioned as a **Lokalise replacement for Flutter-led teams who code with AI** — not an all-in-one TMS. iOS/Android native string files are out of v1 scope (Flutter handles native targets via its own build).

---

## 2. Read these first (in this order)

| Order | Document | Why |
|---|---|---|
| 1 | [`README.md`](README.md) | Elevator pitch, two-step happy path, install + advanced surface. |
| 2 | [`docs/thesis.md`](docs/thesis.md) | The problem Dialect solves and why it solves it this way. |
| 3 | [`docs/roadmap.md`](docs/roadmap.md) | What's shipped vs planned vs explicitly out of scope (v1.1 → v2.0+). |
| 4 | [`docs/architecture.md`](docs/architecture.md) | Convention (flat camelCase keys + `@key.namespace`), CLI reference, `dialect.yaml` shape, check rules, glossary, review UI. |
| 5 | [`docs/cloud.md`](docs/cloud.md) | Dialect Cloud + self-host + OSS local-only — three modes, same protocol. v1.3 target. |
| 6 | [`docs/platforms-frontend.md`](docs/platforms-frontend.md) | Flutter (`gen-l10n`-compatible by design). iOS/Android native adapters dropped — Flutter handles them. |
| 7 | [`docs/platforms-backend.md`](docs/platforms-backend.md) | Backend integration via lossless localizer libraries (no `.resx` adapter); bundle URL pattern in v1.2. |
| 8 | [`docs/ota.md`](docs/ota.md) | Flutter OTA protocol — reuses the v1.2 bundle format; deferred to v2.0+. |
| 9 | [`dialect/spec/icu-json.md`](dialect/spec/icu-json.md), [`flat-json.md`](dialect/spec/flat-json.md) | Versioned on-disk contracts that backend localizer libraries target. |

The brainstorm phase (April–May 2026) is archived at `/Users/chaucao/Documents/github/brainstorm/dialect`. That repo carries the historical planning docs, research, references, and spikes that shaped the design — read them when you need *why* context that isn't in the shipping docs. None of that lives in this repo.

**Local-only shortcut.** A symlink at `.brainstorm/` in this repo points at the brainstorm directory. It's gitignored — never committed. Use it for quick references: e.g. `.brainstorm/planning/cloud-strategy.md`, `.brainstorm/planning/sync-direction-2026-05.md`. Sensitive material (pricing, free-tier economics, "self-host second-class" positioning, infra cost projections) lives in the brainstorm repo by design; the public OSS repo only carries neutral framings.

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

- **ASP.NET** — a documented ~30-line `JsonStringLocalizer` snippet implementing `IStringLocalizer<T>` over Dialect's `icu-json`. Callsites unchanged. A `Dialect.AspNetCore` NuGet that wraps this same snippet behind `services.AddDialectLocalization("wwwroot/locales")` is a **planned nice-to-have**, not a release requirement — the snippet is complete and lossless on its own.
- **Django / Flask / FastAPI / Node / Go** — documented snippet (~10–15 lines), no Dialect-maintained package. Existing libraries (`i18next-fs-backend`, `go-i18n`) already consume Dialect's JSON natively.

A BE engineer adopting Dialect should never have to abandon their stack's localization interface.

### 3.3 ARB-as-universal-source (the convention)

The convention is **flat camelCase keys** + `@key.namespace` metadata + ICU MessageFormat. This is not a Flutter accommodation — it's the best universal source format. ARB is JSON-based, metadata-rich (`description` / `placeholders` / `context` / `namespace`), has ICU built in for plurals/select/gender, and produces identifier-safe keys that work as method names in *every* codegen target (Swift, Kotlin, Dart, TS, C#).

Compare to alternatives as a source format: `.po` (2-form/6-form plural awkwardness, fragile comment-as-context), XLIFF (bloated XML, interchange-not-authoring), i18next JSON (nested dots, no metadata), `.stringsdict` (plural-only), Android XML (escaping nightmare, no metadata), CSV/spreadsheet (no plurals, no metadata). None come close.

Flutter happens to use ARB natively, which is why we lead with the Flutter ICP — but the architecture is universal. Adapters to native iOS `.strings`, Android XML, i18next JSON, etc. are mechanical syntactic transforms, not architectural compromises. They're scope/maintenance decisions, not philosophy decisions.

If a feature would require dotted keys, break ICU MessageFormat, or compromise the metadata richness of `@key` blocks, push back. The convention is the moat — protect it.

### 3.4 Translators review; they don't fill blanks

By the time a key reaches a translator (or Cloud), every locale **already has an AI-generated value**. The AI agent that wrote the screen also generated the translations in the same turn — that's the central DX promise. Translators function as a QA net catching nuance/tone errors, not as a workflow primary that bottlenecks the dev cycle.

**Why this matters:** never frame the workflow as "translators fill in missing translations." UIs, docs, and prompts should default to "review queue" framing. The dashboard never shows "missing in fr/es/de" — it shows status flags (AI-generated-unreviewed / approved / human-edited / stale). This is what differentiates Dialect from Lokalise (which assumes translation is a separate, human-driven phase).

### 3.5 Lokalise-replacement-for-Flutter, not all-in-one TMS

Dialect is **focused**. The README's "Who Dialect is for" / "isn't for" sections explicitly say no to regulated industries needing audit trails, dedicated localization-ops teams, React-web-only teams, solo devs shipping one app in two languages, and shops that can't use AI tools.

If a feature request feels like "let's also do X for audience Y," check those sections first.

### 3.6 Stable JSON contract

`icu-json` and `flat-json` output shapes are versioned. Specs live at [`dialect/spec/icu-json.md`](dialect/spec/icu-json.md) and [`dialect/spec/flat-json.md`](dialect/spec/flat-json.md). Backend localizer libraries (NuGet, snippets) target this contract. Breaking changes require a major version bump. v1.2 adds `dialect/spec/bundle.md` (manifest + per-locale JSON) for `dialect publish` / `dialect pull` / Cloud delivery.

### 3.7 The convention is the product

Cloud, the CLI, the dashboard, the backend libraries — all of them are delivery mechanisms for the underlying convention (ARB-as-source + flat camelCase + `@key.namespace` + ICU MessageFormat + glossary). The convention spreading widely is the long-term win; any specific piece of code is replaceable.

**Implications:**
- Spec-grade docs > marketing-grade docs. The `dialect/spec/` files should read like ECMAScript or HTTP/2 specs — precise, exhaustive, examples for every rule.
- A conformance test suite that third-party tools can run against to claim "Dialect-compatible" is high-leverage and should ship before broad community engagement.
- Reference apps (Flutter + each backend stack) are recruitment material. Build them well.
- `dialect check`'s output quality matters disproportionately — it's the surface most users touch most often, and "this feels like Prettier" perceptions form there.
- Every feature added should make the convention more visible, useful, or credible. Features that don't serve the convention are distractions.

### 3.8 Schema in git, values in DB (the Cloud split)

When Cloud is in the picture, **devs own the schema; translators own the values.**

- **Schema** (which keys exist, their metadata, the English source ARB) is dev-edited, lives in the user's git repo, and is synced UP to Cloud via `dialect push`.
- **Values** (non-English translation strings) live in Cloud's Postgres, are translator-edited via the dashboard, and sync DOWN to local via `dialect pull`.

Cloud is **not** a git proxy. There is no Dialect-owned GitHub App writing PRs back to user repos. Cloud is a normal SaaS with its own database; `dialect export` is the lock-in escape. Self-host = same binary, your infra. OSS local-only = everything in git, Cloud not involved.

---

## 4. Tech stack (locked)

| Component | Stack | Notes |
|---|---|---|
| CLI | **Dart** | `dart compile exe` → ~8 MB self-contained binary. Backend engineers never need the Dart SDK; they install pre-built binaries. |
| Review UI / dashboard | **Svelte 5** (runes) + Vite 8, pnpm-managed | Embedded as static assets in the CLI binary via `tool/build_dashboard.dart`. Served by a Dart Shelf server on `localhost:4077`. No `npm install` for end users. |
| OTA Flutter package (`dialect_ota`) | **Dart** | v1.3+. Thin wrapper around `http` + `shared_preferences` + custom `LocalizationsDelegate`. |
| ASP.NET integration | **C# (`net8.0`)** — documented `JsonStringLocalizer` snippet | Snippet ships today (in `platforms-backend.md`). A `Dialect.AspNetCore` NuGet wrapping it is a **nice-to-have**, not release-blocking. All backend stacks are snippets against the `icu-json` contract. |
| LLM client (for `--auto` mode) | Hand-rolled HTTP over Anthropic / OpenAI REST | v1.2+. ~50 lines per provider. Don't depend on community SDKs. **Always BYO key — Dialect never resells inference.** |
| **Cloud server (`dialect-server`)** — v1.3 | Same Dart Shelf server as `dialect serve`, extended with Postgres + auth + multi-user | Single binary. Deploys to Render (Cloud) or `docker compose` (self-host, v1.4). |
| Database | **Postgres** | Neon (managed) for Cloud; any Postgres for self-host. Code directly against Neon — no abstracted DB driver. |
| Storage / CDN | **Cloudflare R2** + Cloudflare edge | Zero egress — load-bearing for unit economics. S3-compatible everywhere (MinIO for self-host). |
| Cloud auth | GitHub OAuth (devs); magic-link email via Resend (translators) post-MVP | No password DB; GitHub OAuth covers the dogfood audience. |
| Dashboard hosting (Cloud) | **Cloudflare Pages** | Static front-end against the Render-hosted API. |

**Distribution channels (shipping from v1.0):** Pub + Homebrew tap (`ChauCM/homebrew-tap`) + curl install script + GitHub Action (`ChauCM/dialect@v1`). Docker + Scoop are deliberate cuts for v1.0 — revisit if requested. v1.3 adds Cloud sign-in at `dialect.tools`.

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

- **Don't ship a `.resx` adapter.** ASP.NET integration is the documented `JsonStringLocalizer` snippet consuming `icu-json` (a `Dialect.AspNetCore` NuGet wrapping it is a nice-to-have, not required). See Backend Humility (§3.2).
- **Don't ship a gettext `.po` adapter.** Same reasoning.
- **Don't ship `apple-strings` or `android-xml` adapters.** Dropped 2026-05-25 — Flutter handles iOS/Android targets via its own build; native string files are an edge case (method channels, plugins, launch screens) we document as out of v1 scope. See `docs/roadmap.md` and `.brainstorm/planning/sync-direction-2026-05.md`.
- **Don't have Dialect parse source code.** `dialect import` / `dialect describe` write instruction files for the user's AI. Dialect never opens `.dart`, `.kt`, `.swift`, `.cs` files itself.
- **Don't reintroduce dotted keys** (`checkout.bookNow`). They break `flutter gen-l10n`. Use flat camelCase + `@key.namespace` metadata.
- **Don't add a background runtime poller to any backend library.** Dropped 2026-05-25 — backend libs read locale files at app startup; `dialect pull` + redeploy is the live-update mechanism. For sub-minute updates, document the webhook → reload-endpoint pattern, don't ship a poller.
- **Don't make Cloud open auto-PRs back to the user's git via a Dialect-owned GitHub App.** Cloud is a normal SaaS with its own DB (`schema-in-git, values-in-DB`). The lock-in escape is `dialect export`, not git-proxy hacks.
- **Don't bill Cloud users for LLM inference.** `dialect translate --auto` always uses the user's own Anthropic / OpenAI key — Dialect never resells inference, and the public framing is "zero vendor lock-in on AI provider."
- **Don't build a translator marketplace, human-review workflow, or approval chain.** Pin/lock is the v1 answer for "human-approved this translation."
- **Don't ship `dialect translate --auto` as the default `translate` behavior.** The AI-pointer flow is primary; `--auto` is a CI convenience.
- **Don't add telemetry, version-check pings, or any phone-home.** v1.0 anti-goal, holds through Cloud — Cloud only sees data users explicitly `dialect push`.
- **Don't add backwards-compat shims for the pre-1.0 dotted-key convention.** Pre-1.0 had no released users; no migration story needed.
- **Don't frame the dashboard around "missing translations."** Translators review AI-generated values; they don't fill blanks. See principle 3.4.
- **Don't build SSO/SAML, audit log, RBAC beyond per-project membership, multi-region deployment, custom branding, white-label, or any enterprise-compliance features.** These serve <5% of users at high build + maintenance cost. The audience for them is already served by Lokalise / Phrase / Smartling; Dialect isn't competing in that segment.
- **Don't build a paid self-host tier or any license-key-activated Pro features on self-host.** Self-host is community OSS, full stop. No managed self-host product. No "Pro features unlocked by license key" (Sentry / PostHog model) — Dialect's economics don't work at that scale of build effort for that audience size.
- **Don't add a "Contact Sales" pricing tier.** Public pricing only — the moment "contact us" appears, the indie-passive model breaks.
- **Don't sell consulting / migration services as a productized revenue line.** One-off paid help for friends-of-the-project is fine; productizing it is active work that erodes passive economics.
- **Don't accept enterprise inbound** ("we'd pay $50K/yr for SSO + on-prem"). Every yes is months of distraction. The answer is "we don't sell that, sorry — try Lokalise."

---

## 7. Repo layout

```
dialect/
├── bin/                        # Dart CLI entry point
│   └── dialect.dart
├── lib/                        # Dart CLI source
│   ├── adapters/               # Per-platform format conversion (ARB v1.0; icu-json + flat-json land v1.1)
│   ├── arb/                    # ARB parsing + serialization
│   ├── checks/                 # Structural + semantic check rules
│   ├── commands/               # One file per CLI subcommand
│   ├── server/                 # Dart Shelf server for `dialect serve` (extended for `dialect-server` in v1.3)
│   └── templates/              # Generated Dart consts mirroring templates/
├── templates/                  # Canonical text of init scaffolding + plan files
├── dashboard/                  # Svelte SPA for `dialect serve` (extended with auth + multi-project in v1.3)
├── dialect_aspnetcore/         # PLANNED nice-to-have: C# NuGet wrapping the JsonStringLocalizer snippet (not release-blocking)
├── dialect_server/             # PLANNED v1.3: Dart server bootstrap, Postgres migrations, OAuth, REST API
├── dialect_ota/                # Flutter OTA package (v2.0+, deferred — see roadmap)
├── dialect/spec/               # Stable JSON contract docs
│   ├── icu-json.md
│   ├── flat-json.md
│   ├── bundle.md               # PLANNED v1.2: manifest + per-locale JSON for `dialect publish` / Cloud
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
├── .brainstorm                 # Gitignored symlink → ../brainstorm/dialect (sensitive planning)
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

A `Dialect.AspNetCore` NuGet package is a **planned nice-to-have** (not release-blocking): it would live under `dialect_aspnetcore/`, target `net8.0`, and wrap the documented `JsonStringLocalizer` snippet behind `dotnet add package`. For the release, ASP.NET integration is the snippet in `docs/platforms-backend.md`. If/when the package is built, it gets its own `dotnet test` / `dotnet pack` lifecycle, independent of the Dart build.

---

## 9. When to push back

If a future request would:

- Add a backend format adapter (`.resx`, `.po`, `.xliff`)
- Reintroduce `apple-strings` or `android-xml` adapters — Flutter handles native targets via its own build
- Have Dialect parse source code directly
- Reintroduce dotted keys or any non-`gen-l10n`-compatible shape
- Make Dialect call an LLM as the default for semantic work, or have Dialect pay for LLM inference instead of BYO key
- Add a background runtime poller to any backend library (operational overhead; `dialect pull` + redeploy is the answer)
- Make Cloud open auto-PRs back to the user's git via a GitHub App (Cloud is a normal SaaS; `dialect export` is the escape hatch)
- Add enterprise TMS features in v1 (audit log, RBAC, approval chains)
- Target React-web-only / regulated industries / dedicated-loc-ops teams as primary
- Replace `IStringLocalizer<T>` with a Dialect-specific interface
- Frame the dashboard or docs around "missing translations" (translators review, they don't fill blanks)
- Add SSO/SAML, audit log, RBAC beyond per-project, enterprise-compliance features
- Build a paid self-host tier or license-key-gated Pro features on self-host
- Add a "Contact Sales" tier or hide pricing
- Sell consulting/migration services as a productized revenue line
- Add telemetry, version-check pings, or phone-home behavior

…push back and point at the relevant principle. These trade-offs were deliberate.

---

*Brainstorm authored by Chau Cao (April–May 2026). v1.0 implementation completed shortly after. The brainstorm docs are archived at `/Users/chaucao/Documents/github/brainstorm/dialect`.*
