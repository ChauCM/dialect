# Dialect

**AI-native localization for developers who already code with AI.**

---

Developers who code with AI already have the perfect translator sitting right next to them. When you just built a checkout screen in Flutter, your AI co-pilot has full context — the widget tree, the button semantics, the user flow. You can just say *"add the labels on this screen to translations and translate them into Spanish, Japanese, and Arabic"* and it should just work.

**Dialect** is a convention-first, open-source localization toolkit. One canonical source syncs translations across mobile apps and backend services. No dashboard. No context switching. Just code.

> **Project Status:** Dialect is in active design. The architecture below is the target — see the [MVP Plan](planning/mvp-plan.md) for what's shipped vs planned.

```
Dev:  "I just built the checkout screen. Extract all strings,
       add them to dialect/source/en.arb, translate to Spanish and Japanese."

AI:   *reads checkout_screen.dart*
      *adds 12 keys to en.arb with contextual @descriptions*
      *creates/updates es.arb and ja.arb*

Dev:  dialect sync && dialect check
      ✓ Flutter ARB updated
      ✓ iOS .strings updated
      ✓ Android strings.xml updated
      ✓ Go backend JSON updated
      ✓ All 3 locales complete, placeholders match
```

One source. Every platform. 60 seconds.

## Should you use Dialect?

**Yes, if you:**

- Ship Flutter + (iOS native / Android native / a backend) and want one source of truth for translations across platforms
- Already use AI for coding and want to use it for translation too
- Are frustrated by the "add key → context-switch to dashboard → wait → resync to backend" loop
- Don't have a dedicated localization-ops team
- Run a Flutter + ASP.NET / Node / Python / Go stack and want cross-platform sync without forcing your BE team to rewrite their localization layer

**No, if you:**

- Have a dedicated localization-ops team with linguistic QA — use [Lokalise](https://lokalise.com) or [Crowdin](https://crowdin.com)
- Operate in a regulated industry needing translation audit trails, approval chains, or RBAC — use a TMS with compliance features
- Don't allow AI tools in your stack — Dialect's value compounds with AI access; without it, you're using a strict subset
- Ship **React-web-only** — [i18next](https://www.i18next.com) already solves your problem; Dialect would add indirection without proportional value
- Are a solo dev shipping one app in two languages — Dialect is overkill for day-one needs; adopt it when you hit scale

Dialect is **opinionated and focused.** It's a Lokalise replacement for Flutter-led teams who code with AI — not an all-in-one TMS for every localization use case.

## What Dialect Is

1. **A spec** — An opinionated convention for organizing ARB/JSON translation files that any AI produces consistently.
2. **A CLI** — `dialect sync` converts canonical ARB files into platform-specific formats. `dialect check` validates correctness — structurally *and* semantically (catches identical-to-source translations, glossary violations, untranslated English fragments).
3. **A review UI** — `dialect serve` gives non-developers a local web interface to review and edit translations.
4. **OTA support** — Optional over-the-air translation updates via a simple protocol that works with any backend.
5. **AI-readable convention** — `dialect.yaml` includes convention comments that teach any AI assistant the Dialect standard. Editor-agnostic — works with Cursor, Copilot, Windsurf, Claude Code, and anything else.

## What Dialect Is Not

- Not a SaaS platform you depend on.
- Not a replacement for i18next or any runtime i18n library — Dialect generates the files your runtime consumes.
- Not a replacement for your AI assistant — it's the standard your AI assistant follows.

## Quick Start

```
your-project/
├── dialect/
│   ├── dialect.yaml           # Config: locales, platforms
│   ├── source/
│   │   └── en.arb             # Canonical source strings (ARB format)
│   ├── translations/
│   │   ├── es.arb
│   │   ├── ja.arb
│   │   └── ...
│   └── glossary.yaml          # Project-specific terms for consistent AI translation
```

| Command | Description | Status |
|---|---|---|
| `dialect init` | Scaffold the `dialect/` directory | v1.0 |
| `dialect import` | AI-pointer flow: import existing ARBs into Dialect convention | v1.0 |
| `dialect describe` | AI-pointer flow: backfill `@description` from callsites | v1.0 |
| `dialect sync` | Generate platform-specific files from canonical ARBs | v1.0 |
| `dialect check` | Validate completeness, correctness, and translation quality heuristics | v1.0 |
| `dialect status` | Coverage overview across locales | v1.0 |
| `dialect serve` | Local web UI for reviewing translations | v1.0 |
| `dialect translate` | AI-pointer flow for translation (`--auto` for direct LLM call) | v1.2 |
| `dialect publish` | Push translations for OTA delivery | v1.2 |
| `dialect merge` | Key-aware ARB merge driver (opt-in via `dialect init --enable-merge-driver`) | v1.2 |
| `dialect diff` | Show translation changes for PR review | v1.5 |

## Documentation

| Document | Description |
|---|---|
| [Why Dialect](docs/thesis.md) | The problem with localization today and the insight behind Dialect |
| [Architecture](docs/architecture.md) | File convention, CLI reference, config format, CI integration |
| [Mobile Platforms](docs/platforms-frontend.md) | Flutter, iOS, Android — format adapters and OTA. React/RN as secondary. |
| [Backend Platforms](docs/platforms-backend.md) | Node.js, ASP.NET, FastAPI — format adapters, integration patterns |
| [OTA Updates](docs/ota.md) | Over-the-air protocol, publish adapters, and the `dialect_ota` Flutter package |

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

## License

[MIT](LICENSE.md)
