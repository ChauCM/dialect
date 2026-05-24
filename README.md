# Dialect

**AI-native localization for developers who already code with AI.**

Lokalise starts at **$120/seat/month** and ramps fast. For small and medium teams, most of what Lokalise charges for — organizing translation files, AI-assisted translation, keeping mobile + backend in sync — is something your existing AI editor already does for free. Dialect is the convention + CLI that makes "just ask the AI" the actual workflow.

If you're shipping Flutter + a backend, paying for Lokalise to do work your AI can do, and don't need translation memory / multi-step review chains / RBAC / SOC2 audit trails — **swap Lokalise for Dialect.** It's open source, free, and runs on whatever AI editor you already have open.

> v1.0.0-rc.1 — first release candidate, exercising the full release pipeline. See the [MVP plan](planning/mvp-plan.md) for what's shipped vs planned.

---

## Install

```bash
# macOS / Linux — official installer
curl -fsSL https://dialect.tools/install.sh | sh

# macOS / Linux — Homebrew
brew install ChauCM/tap/dialect

# Any platform — Dart pub
dart pub global activate dialect

# GitHub Actions
- uses: ChauCM/dialect@v1
  with:
    args: check --strict
```

Pre-built binaries for `macos-arm64`, `macos-x64`, `linux-x64`, `linux-arm64`, and `windows-x64` are attached to every [release](https://github.com/ChauCM/dialect/releases). Verify the SHA-256 against the release's `SHA256SUMS` asset.

---

## A real day-1 walkthrough

You have a Flutter app with hardcoded English strings (or a `lib/l10n/intl_en.arb`). You want Spanish, Japanese, and Arabic in production. Here's the actual session:

### 1. Scaffold the convention

```bash
$ cd my-flutter-app
$ dialect init

✓ Wrote dialect/
    dialect.yaml         # config + AI-readable convention
    source/en.arb        # your canonical strings (empty)
    translations/        # one file per target locale
    glossary.yaml        # project terms (Book → Reservar, Trip → Viaje, ...)
  Appended .dialect/ to .gitignore

  Next:
    1. Edit dialect/dialect.yaml — set `target_locales: [es, ja, ar]`
    2. Run `dialect import --from arb --path lib/l10n/`
```

Open `dialect/dialect.yaml`. It's heavily commented — those comments are the spec your AI agent reads. You don't have to write the AI prompt yourself; the YAML *is* the prompt.

```yaml
source_locale: en
target_locales: [es, ja, ar]       # ← you edit this

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common, checkout, home, settings]

project:
  name: "My Travel App"
```

### 2. Tell your AI to import your existing strings

```bash
$ dialect import --from arb --path lib/l10n/

Wrote import plan to .dialect/import-plan.md
  Next: open your AI tool (Claude Code, Cursor, Cline, Copilot, …)
  and ask it to follow the plan:
    "Read .dialect/import-plan.md and execute the steps."
```

In your AI editor:

```
> Read .dialect/import-plan.md and execute the steps.

  Reading dialect/dialect.yaml and dialect/glossary.yaml...
  Reading lib/l10n/intl_en.arb (24 strings).
  Reading callsites under lib/ for @description context...

  Renaming keys to namespace.camelCase:
    "book_now"            → "checkout.bookNow"
    "cancel_button"       → "common.cancel"
    "trip_subtitle"       → "checkout.yourTripHeader"
    ... 21 more

  ✓ 24 entries written to dialect/source/en.arb with @description
  ✓ Translated to es/ja/ar respecting glossary.yaml
  ✓ Wrote dialect/translations/{es,ja,ar}.arb

Done. Run `dialect check --fix` to normalize, then `dialect sync`.
```

Dialect itself never opens your `.dart` files — the AI does. Editor-agnostic; works the same in Cursor, Claude Code, Cline, Copilot.

### 3. Validate

```bash
$ dialect check

⚠ dialect/translations/ar.arb:14  glossary  Translation for `checkout.yourTripHeader` does not appear to use the glossary term "Trip" (expected "رحلة").
  hint: Glossary defines "Trip" → "رحلة" in `ar`. If this key uses "Trip"
        in a non-literal sense, add `"glossary_exempt": true` to the
        @key block in the source ARB.

! dialect check: 1 warning (warnings only — exit 0 in soft mode;
  run with --strict in CI)
```

Five structural rules + four semantic heuristics — placeholder mismatches, missing plural categories for the target locale's CLDR rules, identical-to-source translations, length-ratio outliers, glossary violations, untranslated-English fragments. Every issue has a `file:line` and a real remediation hint.

### 4. Generate platform files

```bash
$ dialect sync

✓ Wrote lib/l10n/app_en.arb
✓ Wrote lib/l10n/app_es.arb
✓ Wrote lib/l10n/app_ja.arb
✓ Wrote lib/l10n/app_ar.arb
```

Flutter `gen_l10n` picks these up directly. iOS `.strings` / Android `strings.xml` / backend `flat-json` & `icu-json` adapters land in v1.1; the canonical spec contracts are already locked under [`dialect/spec/`](dialect/spec/).

### 5. Review in the browser

```bash
$ dialect serve

Dialect Review running at http://localhost:4077
Reading from: ./dialect/
```

Open the URL. Every key, every locale, side by side with `@description` context and glossary highlighting. Inline edits save back to ARB on blur. Lock human-reviewed translations to skip them on the next `dialect translate` run.

### 6. CI gate on every PR

`.github/workflows/dialect.yml`:

```yaml
name: Dialect
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ChauCM/dialect@v1
        with:
          args: check --strict
```

`--strict` promotes warnings to errors, so a missing placeholder, an orphan `@key` block, or a glossary violation fails the build.

### 7. Coverage view

```bash
$ dialect status

┌────────┬──────────┬───────┬─────┬────────┐
│ Locale │ Coverage │ Stale │ New │ Locked │
├────────┼──────────┼───────┼─────┼────────┤
│ es     │    100%  │     0 │   0 │      0 │
│ ja     │    100%  │     0 │   0 │      0 │
│ ar     │     95.8% │     0 │   1 │      0 │
└────────┴──────────┴───────┴─────┴────────┘
```

That's the whole product. ~10 commands, no SaaS, no seat tax.

---

## Layout & command reference

```
your-project/
├── dialect/
│   ├── dialect.yaml           # Config + AI-readable convention
│   ├── source/
│   │   └── en.arb             # Canonical source strings (ARB format)
│   ├── translations/
│   │   ├── es.arb
│   │   ├── ja.arb
│   │   └── ...
│   └── glossary.yaml          # Project-specific terms for consistent AI translation
├── .dialect/                  # Gitignored. AI-pointer plan files land here.
└── lib/l10n/                  # `dialect sync` output (Flutter convention)
```

| Command | Description | Status |
|---|---|---|
| `dialect init` | Scaffold the `dialect/` directory | v1.0 |
| `dialect import` | AI-pointer flow: import existing ARBs into the convention | v1.0 |
| `dialect describe` | AI-pointer flow: backfill `@description` from callsites | v1.0 |
| `dialect sync` | Generate platform-specific files from canonical ARBs | v1.0 |
| `dialect check` | Validate completeness, correctness, and translation quality heuristics | v1.0 |
| `dialect status` | Coverage overview across locales | v1.0 |
| `dialect serve` | Local web UI for reviewing translations | v1.0 |
| `dialect translate` | AI-pointer flow for translation (`--auto` for direct LLM call) | v1.2 |
| `dialect publish` | Push translations for OTA delivery | v1.2 |
| `dialect merge` | Key-aware ARB merge driver (opt-in via `dialect init --enable-merge-driver`) | v1.2 |
| `dialect diff` | Show translation changes for PR review | v1.5 |

---

## Documentation

| Document | Description |
|---|---|
| [Why Dialect](docs/thesis.md) | The problem with localization today and the insight behind Dialect |
| [Architecture](docs/architecture.md) | File convention, CLI reference, config format, CI integration |
| [Mobile Platforms](docs/platforms-frontend.md) | Flutter, iOS, Android — format adapters and OTA. React/RN as secondary. |
| [Backend Platforms](docs/platforms-backend.md) | Node.js, ASP.NET, FastAPI — format adapters, integration patterns |
| [OTA Updates](docs/ota.md) | Over-the-air protocol, publish adapters, and the `dialect_ota` Flutter package |

### Stable on-disk contracts (`dialect/spec/`)

These specify Dialect's versioned file formats. Backend localizer libraries (`Dialect.AspNetCore`, third-party adapters) target this contract; breaking changes require a major-version bump.

| Spec | Description |
|---|---|
| [`icu-json`](dialect/spec/icu-json.md) | Backend JSON output that preserves ICU plural/select expressions byte-identically |
| [`flat-json`](dialect/spec/flat-json.md) | Backend JSON output that strips ICU plural/select to a plain string (takes the `other` branch) |
| [`@key.source_hash`](dialect/spec/source_hash.md) | Source-value fingerprint that powers `dialect status` "stale" and the dashboard lock indicator |
| [`.dialect/state.json`](dialect/spec/state.md) | Soft-mode acknowledgement store for the `dialect check` rules |

---

## Internal Planning

Design decisions, business analysis, and build roadmap are in [`planning/`](planning/):

| Document | Description |
|---|---|
| [Original Brainstorm](planning/original-brainstorm.md) | The full brainstorm that started this project |
| [Naming Research](planning/naming-research.md) | How we chose "Dialect" — name collision research, alternatives considered |
| [Business Analysis](planning/business-analysis.md) | Viability assessment, monetization paths, competitive landscape |
| [MVP Plan](planning/mvp-plan.md) | v1 tooling roadmap, v2 business layer, effort estimates, success metrics |
| [Dashboard Design](planning/dashboard-design.md) | Review UI mockups, local vs hosted architecture, what to skip |
| [Competitive Strategy](planning/competitive-strategy.md) | Target audience, i18next relationship, cross-platform sync as the moat |

## Research

AI-generated analysis and market deep-dives are in [`research/`](research/).

## References & Spikes

- [`references/repos.md`](references/repos.md) — External repos to study for architecture decisions
- [`spikes/`](spikes/) — Quick technical experiments to validate assumptions

---

## What Dialect is

Five things, in order of "what you touch":

1. **A convention.** An opinionated way to organize ARB files with rich `@description` / `@placeholders` / glossary metadata, plus a YAML config that doubles as an AI-readable instruction sheet. Any modern AI editor produces correct output by reading it.
2. **A CLI.** `init` scaffolds, `import` / `describe` write structured plan files the AI follows, `check` validates structurally and semantically, `sync` generates platform files, `status` reports coverage.
3. **A local review UI** (`dialect serve`). A Svelte SPA embedded in the binary; no `node_modules` at runtime. Side-by-side source + target, glossary highlighting, inline edit, pin/lock.
4. **Versioned on-disk contracts** ([`dialect/spec/`](dialect/spec/)). Backend localizer libraries target the spec, not the CLI version — breaking changes require a major bump.
5. **OTA support** (v1.3+). Optional over-the-air translation updates via a simple protocol that works with any backend.

## Who Dialect is for

Small and medium teams currently paying for Lokalise / Crowdin / Phrase, who:

- Ship **Flutter + a backend** (ASP.NET, Node, Python, Go) and need cross-platform sync.
- **Already code with AI** — Claude Code, Cursor, Cline, Copilot — and want the same workflow for translation.
- Don't have a dedicated localization-ops team, RBAC requirements, or audit-trail compliance needs.
- Would rather own their translation files in git than rent a dashboard.

## License

[MIT](LICENSE)
