# Dashboard Design

How the review UI works, what it looks like, how it evolves from local tool to hosted service.

---

## Why a Dashboard at All

Dialect is developer-first and AI-first, but translations ultimately serve users in real markets. There are cases where the developer/AI loop isn't enough:

- **Cultural nuance.** A native speaker notices the AI translated "Cancel" as the destruction verb, not the "undo" verb.
- **Brand-specific wording.** Marketing insists on "Reserve" instead of "Book" for the Japanese market.
- **Legal/political sensitivity.** A locale requires specific phrasing for regulatory compliance.
- **User feedback.** A support ticket says "this label is confusing in Arabic" — a PM needs to see the string and context without cloning the repo.

The dashboard exists for these edge cases. It's not the primary workflow — it's the safety net.

---

## v1: Local Review UI (`dialect serve`)

Ships as part of the CLI. No hosting, no accounts, no setup beyond running the command.

### Architecture

```
┌───────────────────────────────────────┐
│           dialect serve               │
│                                       │
│   ┌─────────┐     ┌───────────────┐  │
│   │  Shelf   │────▶│  dialect/     │  │
│   │  Server  │◀────│  (ARB files)  │  │
│   │  :4077   │     └───────────────┘  │
│   └────┬────┘                         │
│        │                              │
│   ┌────▼────┐                         │
│   │  SPA    │  (embedded static       │
│   │  Assets │   assets in CLI binary) │
│   └─────────┘                         │
└───────────────────────────────────────┘
```

A Dart Shelf server reads and writes to the local `dialect/` directory. The SPA is pre-built and bundled into the CLI binary — no npm, no build step for the user. Open browser, see translations, edit, save.

### UI Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  Dialect Review                              [es ▼]  [Search...  ] │
├───────────────────┬─────────────────────────────────────────────────┤
│                   │                                                 │
│  Filters          │  Key              │ English        │ Spanish    │
│                   │                                                 │
│  ☐ Missing only   │  checkout.bookNow │ Book Now       │ Reservar ▍│
│  ☐ Locked         │  (CTA button on checkout screen,                │
│  ☐ Stale          │   verb: make a reservation)                     │
│                   │─────────────────────────────────────────────────│
│  Namespace        │  checkout.items   │ {count} items  │ {count}   │
│  ☐ common         │  (Item count on checkout)          │ artículos │
│  ☐ mobile         │─────────────────────────────────────────────────│
│  ☐ web            │  settings.notif   │ Notifications  │ ⚠ missing │
│  ☐ backend        │  (Settings screen toggle label)    │ [Add ▸]   │
│                   │─────────────────────────────────────────────────│
│  Feature          │  settings.dark    │ Dark Mode      │ Modo      │
│  ☐ checkout       │  (Theme toggle)   │                │ Oscuro 🔒 │
│  ☐ settings       │                                                 │
│  ☐ profile        │                                                 │
│                   │                                                 │
├───────────────────┴─────────────────────────────────────────────────┤
│  es: 247/250 translated (98.8%)  │  3 missing  │  2 locked         │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Interactions

- **Inline edit.** Click a target cell → it becomes editable → type → save (writes ARB file immediately).
- **Lock/pin.** Mark a translation as human-approved. Adds `"@key": { "locked": true }` to the ARB metadata. `dialect translate` skips locked keys.
- **Missing indicator.** Keys present in source but absent in target show a warning with a quick-add button.
- **Context display.** The `@key` description from the ARB file appears below each row, giving reviewers context without reading code.
- **Glossary highlight.** When a glossary term appears in the source string, it's highlighted and the expected translation is shown on hover.
- **Locale switcher.** Dropdown to switch between target locales. Source locale is always visible on the left.

### REST API Surface

```
GET  /api/config              → dialect.yaml contents
GET  /api/strings?locale=es   → all keys with source, target, metadata, lock status
PUT  /api/strings/:key        → { "locale": "es", "value": "Reservar", "locked": true }
GET  /api/glossary            → glossary terms and style rules
GET  /api/status              → per-locale coverage stats
```

All reads come from the local ARB files. All writes go back to the same files. No database, no state beyond the filesystem.

---

## v2: Hosted Review Dashboard

If v1 gets traction and teams want remote access for non-developers, the same SPA can be deployed as a hosted service.

### What Changes from v1 to v2

| Aspect | v1 (Local) | v2 (Hosted) |
|---|---|---|
| Data source | Local filesystem | GitHub repo via API |
| Auth | None (localhost) | GitHub OAuth |
| Multi-user | Single user | Role-based (reviewer, editor, admin) |
| Persistence | Direct file write | Commits to a branch, creates PR |
| Comments | None | Comment threads per string |
| History | Git log | In-app audit trail + git log |
| Deployment | CLI binary | Hosted SPA + API service |

### How Hosted Sync Works

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  GitHub Repo │◀───▶│  Dialect Cloud   │◀───▶│  Browser     │
│  (ARB files) │     │  API             │     │  (SPA)       │
└──────────────┘     └──────────────────┘     └──────────────┘
```

1. User connects their GitHub repo to Dialect Cloud.
2. The API reads ARB files from the repo.
3. Reviewers edit translations in the browser.
4. Edits are committed to a `dialect/review` branch.
5. When the reviewer is done, a PR is created for the dev to merge.

Translations always live in the repo. Dialect Cloud never becomes the source of truth — it's a read-write window into git.

---

## What NOT to Build

These features are tempting but would turn Dialect into a full TMS (translation management system). That's a different product with different economics.

- **Translation workflow states** (draft → review → approved → published). Overkill for the edge-case use pattern.
- **Translator assignment and routing.** Dialect isn't a marketplace for translators.
- **In-context visual preview** (rendering the actual app UI with translations). Requires maintaining a build pipeline per platform per customer.
- **Machine translation comparison** (show 3 LLM outputs side-by-side for picker). Nice to have but adds significant complexity and cost.
- **Real-time collaborative editing.** CRDTs, WebSocket sync, conflict resolution — too much infrastructure for occasional review.
- **Translation memory database.** Tempting for enterprise but requires a whole persistence and matching layer. Consider for v2.3+ if enterprise demand is real.

---

## Tech Stack Options Considered

### SPA Framework

| Option | Bundle Size | Reasoning |
|---|---|---|
| **Preact** | ~4 KB | React-compatible API, tiny bundle, large ecosystem. Best default choice. |
| Svelte | ~2 KB | Even smaller, but smaller ecosystem. Good if you want zero-dependency purity. |
| Alpine.js | ~15 KB | Sprinkles interactivity on HTML. Great for small UIs but gets messy for a table-heavy app. |
| React | ~40 KB | Overkill for what's essentially a data table with filters. |

**Recommendation: Preact.** It's React-compatible (easy to find contributors), tiny enough to embed in a CLI binary, and has the ecosystem to support a table-heavy UI (e.g., preact-virtual-list for large translation sets).

### Local Server

Dart Shelf is the obvious choice — it ships with the Dart SDK, the CLI is already in Dart, and we can embed the SPA as static assets using `dart compile exe` with asset bundling.

### Hosted Service (v2)

If/when v2 happens, the API layer can be rewritten in any backend language depending on what the team looks like. The SPA stays the same. The API contract is tiny (5 endpoints), so the backend is swappable.

---

## Priority Relative to Other v1 Work

`dialect serve` lives in v1.3, after the core CLI and OTA are working. The reasoning:

1. **v1.0–v1.2** establish the convention, the CLI, multi-platform sync, AI translation, and OTA. These are the features that attract developers and prove the thesis.
2. **v1.3** adds `dialect serve` alongside the OTA client package. By this point, early adopters will have real translation files and the review UI becomes immediately useful.
3. Shipping the review UI early (rather than post-launch) means the first public demo can show the full loop: developer writes code → AI translates → PM reviews in browser → ship.

That full-loop demo is the strongest pitch for Dialect as a complete replacement for tools like Lokalise, not just a dev utility.
