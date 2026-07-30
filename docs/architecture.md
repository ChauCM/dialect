# Architecture

Dialect has five components: a file convention (the spec), a CLI tool, a local review UI, an optional Cloud / self-host server (v1.3+), and an optional Flutter OTA delivery system (v2.0+).

> **Roadmap context.** See [`roadmap.md`](roadmap.md) for what's shipped vs. planned. This doc describes the convention + CLI shape; v1.1 adds `icu-json` / `flat-json` adapters, v1.2 adds `dialect publish` / `dialect pull`, v1.3 adds Cloud + `dialect-server`. **iOS / Android native string-file adapters are not on the roadmap** — Flutter handles native targets via its own build.

---

## Project Structure

```
your-project/
├── dialect/
│   ├── dialect.yaml           # Config + AI convention (the one file AI assistants read)
│   ├── source/
│   │   └── en.arb             # Canonical source strings
│   ├── translations/
│   │   ├── es.arb
│   │   ├── ja.arb
│   │   ├── ar.arb
│   │   └── ...
│   └── glossary.yaml          # Project-specific terms
```

ARB (Application Resource Bundle) is the canonical format. It's JSON with metadata support for descriptions, placeholders, and ICU MessageFormat pluralization — native to Flutter, readable by any AI or tool.

---

## Key Naming Convention

Canonical keys are **flat camelCase Dart identifiers** with logical grouping carried in metadata:

- Keys are valid Dart method names — letters, digits, underscores; no dots, no dashes, no leading digit. This is required by Flutter's `flutter gen-l10n`, which generates one `AppLocalizations` method per key.
- The logical group lives in **`@key.namespace`** metadata (`checkout`, `settings`, `common`, `mobile`, `web`, `backend`). The namespace controls per-platform sync filtering and how cross-platform adapters group output (e.g. one `.strings` file per namespace on iOS).
- Keys are always **sorted alphabetically** in ARB files. `dialect sync` enforces this ordering to produce deterministic output and minimize git diff noise.

Examples: `checkoutBookNow`, `checkoutItemCount`, `commonLoading`, `settingsDarkMode`.

Source keys without `@key.namespace` are flagged by `dialect check` — the namespace drives platform filtering, so it's mandatory in the source ARB.

---

## Source Strings

```json
{
  "@@locale": "en",
  "checkoutBookNow": "Book Now",
  "@checkoutBookNow": {
    "namespace": "checkout",
    "description": "CTA button on checkout screen, verb meaning 'make a reservation'",
    "context": "checkout_screen"
  },
  "checkoutItemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "@checkoutItemCount": {
    "namespace": "checkout",
    "description": "Item count display on checkout screen",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "commonLoading": "Loading...",
  "@commonLoading": {
    "namespace": "common",
    "description": "Generic loading indicator, shared across all platforms"
  }
}
```

The `@key` metadata provides context for translation. When an AI extracts strings, it fills `namespace` + `description` automatically. When translating, it reads them to produce accurate results.

Keys are sorted alphabetically — `checkoutBookNow` before `commonLoading`. This ordering is enforced by `dialect sync` and expected by `dialect check`.

---

## CLI Reference

```bash
# Local commands — work offline against the dialect/ directory
dialect init                    # Scaffold the dialect/ directory
dialect import                  # AI-pointer flow: import existing ARBs into Dialect convention
dialect describe                # AI-pointer flow: backfill @description from callsites
dialect sync                    # Generate platform-specific files from canonical ARBs
dialect check                   # Validate completeness and correctness
dialect status                  # Coverage overview across locales
dialect translate               # AI-pointer flow: translate missing keys (--auto for direct LLM call)
dialect serve                   # Local web UI for reviewing and editing translations
dialect diff                    # Show translation changes (for PR comments)

# Bundle commands (v1.2) — talk to S3 / R2 / git / local
dialect publish <env>           # Build versioned bundle, upload to configured target
dialect pull                    # Fetch latest bundle into dialect/translations/

# Server commands (v1.3) — talk to dialect-server (Cloud at dialect.tools, or self-host)
dialect login [--server <url>]  # GitHub OAuth flow; writes ~/.config/dialect/auth.json
dialect link <project-slug>     # Associate this repo with a server project
dialect push                    # Send source ARB + AI-generated translations up to server
dialect export                  # Full project tarball — migration / backup
```

**Design principle.** Commands split into two categories:

- **Syntactic** (`sync`, `check`, `status`, `diff`, `publish`, `push`, `pull`) — deterministic format conversion, validation, file transfer. Dialect does this itself.
- **Semantic** (`import`, `describe`, `translate`) — needs intelligence: read code, understand context, produce natural language. Dialect writes a structured instruction file (`.dialect/*-plan.md`) and the user's existing AI agent (Cursor, Claude Code, Cline, Copilot, …) executes it. No model API keys, no vendor lock, no staleness as models evolve.

### `dialect init`

The agent-executable entry point. Scaffolds the `dialect/` directory *and* writes `.dialect/init-plan.md` — a two-phase playbook the user's AI agent executes end-to-end. Also writes (or appends to) `AGENTS.md` (or `CLAUDE.md` if that's the only one present) so future agent sessions on the same project pick up Dialect's conventions automatically.

```
$ dialect init
✓ Scaffolded dialect/
  dialect/dialect.yaml
  dialect/glossary.yaml
  dialect/source/en.arb
  dialect/translations/  (empty)
  .dialect/init-plan.md
  AGENTS.md (created)
  .gitignore (added .dialect/)

Detected project type: Flutter
Init plan written to: .dialect/init-plan.md

Next: paste this in your AI agent (Claude Code, Cursor, …):

  run dialect init and follow the instructions
```

The plan splits into **Phase 1 (Setup)** — deps, `l10n.yaml`, `MaterialApp` wiring, locale switcher, smoke test — and **Phase 2 (Extract + translate)**. Phase 2 has one sizing rule: ≤50 candidate strings → AI does it end-to-end in one chat turn; >50 → AI does extraction only, then stops for the developer to glance at key names before the long translation step. Re-running `dialect init` is idempotent — it refreshes the plan but leaves the scaffold alone unless `--force` is passed.

### `dialect import`

For projects that already have localization files. Writes `.dialect/import-plan.md` — a structured instruction file telling the user's AI agent how to convert existing ARB / `.strings` / etc. into Dialect's convention. The agent:

- Reads source files from the path the user supplied (e.g. `lib/l10n/`).
- Renames keys to flat camelCase Dart identifiers (`checkoutBookNow`) and adds `@key.namespace` metadata.
- Backfills `@description` by reading the callsites that reference each key.
- Applies `glossary.yaml` rules.
- Writes the result to `dialect/source/en.arb`.

```bash
$ dialect import --from arb --path lib/l10n/
✓ Wrote import plan to .dialect/import-plan.md
  Next: open your AI tool (Claude Code, Cursor, Cline, Copilot, …) and run:
    "Read .dialect/import-plan.md and execute the steps."
$ dialect check
```

Dialect itself never parses the source files — the user's AI does. This keeps Dialect editor-agnostic, model-agnostic, and small.

### `dialect describe`

Same AI-pointer pattern, scoped to backfilling `@description`. Writes `.dialect/describe-plan.md` instructing the agent to scan callsites and fill any missing description fields. Run this after `dialect import` or whenever new keys land without descriptions. Higher-quality descriptions multiply the quality of every downstream operation that reads them (translation, glossary matching, review UI).

### `dialect sync`

Reads canonical ARB files and generates platform-specific outputs:

```
dialect/source/en.arb (canonical)
       │
       ├──▶ lib/l10n/app_en.arb                        (Flutter — direct copy)
       └──▶ api/locales/en.json                         (Backend — flat-json or icu-json, v1.1)
```

The CLI is a format converter. It doesn't translate. It doesn't parse code. It keeps Flutter + backend files in sync from one canonical source.

**Out of scope.** Native iOS `.strings`/`.stringsdict` and Android `strings.xml` are **not** sync targets. Flutter's own build pipeline produces iOS/Android-compatible output from `AppLocalizations`; standalone native string files only matter for edge cases (method channels, native plugins, launch screens). See [Frontend Platforms](platforms-frontend.md) for the gap and recommended workarounds.

See [Frontend Platforms](platforms-frontend.md) and [Backend Platforms](platforms-backend.md) for detailed integration guides.

**Ergonomics:** `dialect sync --dry-run` (list what would change without writing; exits non-zero if anything is out of date) and `--platform <name>` (sync one configured platform) ship today. `--watch` (foreground re-sync on file change) is still planned. A `flat-json` platform prints a per-platform lossy-event line listing the keys whose ICU plurals were collapsed to the `other` branch.

**Sync reports where it left you.** Every write ends with one line — `check: no issues.` or a count of errors and warnings — because the trailing `dialect check` in the documented loop asks a question sync already knows the answer to. The report is unconditional and free; the *exit code* is not, unless you pass `--verify`, which makes any remaining error a non-zero exit and turns CI into one command. Without it the exit code is unchanged: the files are on disk by then either way, and a report on the project's state is not a verdict on whether the write succeeded. `--dry-run` wrote nothing, so it reports nothing. Acknowledgements apply here exactly as in `dialect check`.

### `dialect check`

Validates translation completeness and correctness:

```bash
$ dialect check
  ✓ 247 keys across 6 locales
  ✗ ar.arb: missing plural category 'two' for key 'checkoutItemCount'
  ✗ ja.arb: missing key 'settingsNotifications'
  ⚠ es.arb: 'checkoutBookNow' still contains English text
```

**Structural checks** (deterministic, fast):
- Every source key exists in all target locale files.
- Placeholder variables match across translations.
- ICU plural categories are valid for each locale.
- No empty values left in locale files.

**Semantic heuristics** (deterministic, no AI required — catch the most common `dialect translate` failure modes):

- **Source-equality.** Flag any translation whose value equals the source value. This is the most frequent LLM translation failure: the model silently passes the English string through for terms it doesn't recognize. Catching it here is the difference between "Dialect-translated app looks polished" and "Dialect-translated app has untranslated strings in production."
- **Length ratio.** Flag translations outside `[0.3×, 2.5×]` of source character length. Configurable per-locale in `dialect.yaml` (German runs long, Japanese can run short). Warning severity — false positives are common, so this never escalates to error in strict mode without explicit opt-in.
- **Untranslated English fragments.** Regex for English-looking word sequences in non-English locale files. Catches partial translations where the model translated some clauses but left others in English.
- **Glossary enforcement.** For every glossary term that appears in a source string, check the corresponding translation contains the prescribed translation from `glossary.yaml`. Escape hatch: `@key.glossary_exempt: true` for keys where the term is used non-literally. This is what makes `glossary.yaml` load-bearing instead of decorative.
- **Plural shape.** Flag a source string that interpolates a count straight in front of a plural noun — `"{count} people"`, which renders "1 people". `plural_categories` checks that a plural is *complete* once one exists; this checks that one exists at all. Source-side only: once the source is a plural, every translation inherits the shape. A placeholder is read as a count from its declared `type` (`int` / `num` / `double` / `number`) or from a conventional name, and the rule fires only when the noun it governs is already plural — which is precisely the disagreement, and what keeps it quiet enough to default on.
- **Banned patterns.** Flag any value, source included, containing copy the project has ruled out — the inverse of glossary enforcement, read from the `banned:` block of `glossary.yaml`. See [copy policy](#copy-policy-glossaryyaml).
- **Stale translations.** Flag any translation whose recorded `@key.source_hash` no longer matches the current English source — i.e. the source changed after the translation was written, so the translation is potentially out of date (locked *or* unlocked). This is the change-half of the sync loop. `dialect check --fix` stamps the hash onto unlocked translations as provenance; the warning is resolved by re-translating (`dialect translate` refreshes it) or by locking the value if it's still correct (locking re-stamps it). Not `--ack`-able — it's a fact about provenance, not a heuristic, so the fix is to refresh, not silence. See [`dialect/spec/source_hash.md`](../dialect/spec/source_hash.md).

```bash
$ dialect check
  ✓ 247 keys across 6 locales (structural)
  ⚠ es.arb: 'checkout.bookNow' identical to source ("Book Now")
  ⚠ de.arb: 'checkout.itemCount' length 3.4× source (limit 2.5×)
  ✗ ar.arb: missing plural category 'two' for key 'checkout.itemCount'
  ⚠ ja.arb: glossary term 'Book' should translate to '予約する', found '本'
    Hint: if this is a non-literal usage, add @ja.bookList: { glossary_exempt: true }
```

**Soft mode (default) vs strict (`--strict`).** On a fresh import (or when no `.dialect-state` lock exists), `dialect check` emits warnings with helpful hints ("run `dialect describe`" / "run `dialect translate`") instead of erroring. `--strict` is for CI — every warning becomes a hard failure (except length-ratio, which stays a warning unless `--strict-length` is also passed). The soft-default removes the "imported and immediately broken" experience on day one.

**Acknowledging a warning (`--ack`).** When a soft warning is intentional (e.g. "Email" is the canonical Vietnamese form, so `source_equality` firing is noise), dismiss it without flipping CI to strict:

```bash
dialect check --ack source_equality:vi:settingsEmailLabel --note "Email is canonical in vi"
```

This writes `.dialect/state.json` (workspace-local, gitignored), fingerprinting the source/translation value at ack-time per [`dialect/spec/state.md`](../dialect/spec/state.md). The warning stays hidden until that value changes — at which point it re-fires and the report flags the ack as stale (`⚠ stale-ack …`) so you can re-ack or delete it. Only the heuristic rules (`banned_pattern`, `glossary`, `length_ratio`, `plural_shape`, `source_equality`, `untranslated_english`, `width_budget`) are ack-able; structural rules are correctness failures and can't be silenced. Passing an unknown rule to `--ack` prints the current list, read from the same map the suppression logic uses, so the message can't drift from what is actually ack-able.

### Copy policy (`glossary.yaml`)

`glossary.yaml` is the project's copy policy, and it carries both directions of the same question. `terms:` says *always say this* and is enforced by the `glossary` rule. `banned:` says *never say that* and is enforced by `banned_pattern`, across the source as well as every translation — a rule about a turn of phrase is usually written about the original language, so scoping it to translations would leave the locale it was written for unchecked.

```yaml
banned:
  - pattern: "—"
    reason: "Use a comma, a colon, or two sentences."
    except: [pushBodyJourneyFirstStep]
  - pattern: '\b(utilize|leverage)\b'
    regex: true
    reason: "Prefer the plain verb: 'use'."
    locales: [en]
```

`pattern` is literal by default so punctuation needs no escaping; `regex: true` opts in. `reason` is required, because it is printed as the hint and is the whole value of the finding. Both rules are warnings, so `--strict` is what turns a copy convention into a CI gate.

**Two kinds of exception, because copy policy has two.** `dialect check --ack banned_pattern:LOCALE:KEY` waives one use and expires when that value is edited, which is right for "this particular sentence is fine." A house style that *rules* a set of keys exempt is not that — it has to survive a typo fix — so those keys go in `except:`. A standing list is the artefact that rots, so the rule audits its own: a name in `except:` whose value no longer contains the pattern is reported, and the list can only shrink.

Both blocks are per-project and read by every consumer of the source, which is the point — a copy rule enforced by a test in one stack does not protect the app, the backend, and the website that all render the same strings.

### `dialect status`

```bash
$ dialect status
┌─────────┬──────────┬───────┬───────┐
│ Locale  │ Coverage │ Stale │ New   │
├─────────┼──────────┼───────┼───────┤
│ es      │ 98.5%    │ 3     │ 12    │
│ ja      │ 97.2%    │ 5     │ 12    │
│ ar      │ 95.0%    │ 8     │ 12    │
└─────────┴──────────┴───────┴───────┘
```

### `dialect translate`

AI-pointer flow primary, direct LLM call as convenience.

**Default (recommended):** writes `.dialect/translate-plan.md` instructing the user's AI agent to read the source locale, identify missing keys per target locale, consult `glossary.yaml`, and write valid ARB back. Model-agnostic, vendor-neutral, doesn't go stale.

```bash
$ dialect translate
✓ Wrote translate plan to .dialect/translate-plan.md
  Next: open your AI tool and run:
    "Read .dialect/translate-plan.md and execute the steps."
```

**`--auto` (for CI / scripting):** Dialect calls the LLM directly. Use when no human-in-the-loop agent is available.

```bash
dialect translate --auto --provider anthropic
dialect translate --auto --provider openai --model gpt-4.1
```

### `dialect serve`

Starts a local web UI for reviewing and editing translations. Non-developers (PMs, translators, legal) can browse strings, see context, and make targeted edits without touching code or ARB files directly.

```bash
$ dialect serve
Dialect Review running at http://localhost:4077
Reading from: ./dialect/
```

Opens a browser with a translation table showing source strings alongside each target locale. Edits save directly back to the local ARB files. See the [Review UI](#review-ui) section below for details.

### `dialect publish` (v1.2)

Builds an **immutable, content-hashed bundle** (manifest.json + per-locale JSON files in `icu-json` or `flat-json` shape) and uploads to a user-configured target.

```bash
dialect publish prod              # Build bundle, upload to target configured in dialect.yaml
dialect publish staging --dry-run # Show what would happen, don't upload
```

```yaml
# dialect.yaml
publish:
  production:
    target: s3            # or r2 | git | local
    bucket: my-bucket
    prefix: locales/prod/
    manifest_url: https://cdn.example.com/locales/prod/manifest.json
  staging:
    target: local
    path: dist/locales/
```

The published bundle format is specified in [`dialect/spec/bundle.md`](../dialect/spec/bundle.md). Backend libraries fetch the manifest URL at app startup — no background poller; live updates happen via `dialect pull` in CI + redeploy.

`dialect publish` against a `dialect-server` (Cloud or self-host) targets the server's `/publish` endpoint, which builds the bundle and uploads to Cloud-managed R2 (or your S3-compatible bucket in self-host). Same protocol either way.

### `dialect pull` (v1.2)

Fetches the latest bundle for a configured environment and writes per-locale JSON into `dialect/translations/`. Use in CI deploy scripts:

```bash
# In CI before deploying the backend
dialect pull
dotnet publish --configuration Release
```

### `dialect login` / `link` / `push` / `export` (v1.3)

CLI commands for talking to `dialect-server` (the Cloud instance at `dialect.tools`, or a self-host instance). See [`cloud.md`](cloud.md) for the full picture.

```bash
dialect login                          # GitHub OAuth flow, defaults to dialect.tools
dialect login --server https://dialect.mycompany.com   # Self-host
dialect link my-app-slug               # Associate this repo with a project
dialect push                           # Send source ARB + AI translations up
dialect pull                           # Fetch translations down (works for both server-linked and bucket-only configs)
dialect export --out my-app.tar.gz     # Full project snapshot for migration
```

### `dialect diff`

Shows what changed in translations. Useful for PR review:

```bash
dialect diff --format markdown >> pr-comment.md
```

---

## Config: `dialect.yaml`

`dialect.yaml` is both the project configuration and the AI instruction file. The header comments teach any AI coding assistant (Cursor, Copilot, Windsurf, Claude Code, Cline, Aider — anything that reads files) how to work with this project's translations. No vendor-specific config file needed.

A developer points their AI at this file: *"read dialect/dialect.yaml and then extract all strings from this screen."* The comments give the AI everything it needs to produce correct output.

```yaml
# ============================================================
# Dialect — Localization Convention
# ============================================================
# This file configures Dialect AND teaches AI assistants how
# to work with this project's translations.
#
# AI Instructions:
#   - Canonical source strings live in dialect/source/*.arb
#   - Keys are flat camelCase Dart identifiers
#     e.g. checkoutBookNow, commonCancel, settingsDarkMode
#   - Every key MUST have a matching @key with:
#       "namespace" — the logical group (checkout, common, settings…)
#       "description" — what the string means in context
#   - Placeholders use ICU MessageFormat: "Hello {userName}"
#     with @key.placeholders describing each variable
#   - Plurals use ICU select: "{count, plural, one{...} other{...}}"
#   - Keys are always sorted alphabetically within each ARB file
#   - Check dialect/glossary.yaml for project-specific terms
#     and required translations before translating
#   - When you add new keys, also generate translations for every
#     target locale in the same turn — translators review, they
#     don't fill blanks
#   - After editing ARB files, run:
#       dialect check --fix && dialect sync
#     (sync re-checks and reports; --verify makes it the gate)
# ============================================================

source_locale: en
target_locales: [es, ja, ar, de, fr, zh]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common, mobile]

  backend:
    output: api/locales/
    format: flat-json      # use icu-json if backend needs pluralization
    namespaces: [common, backend]

# Optional: bundle publishing (v1.2+)
# publish:
#   production:
#     target: s3
#     bucket: my-bucket
#     prefix: locales/prod/
#     manifest_url: https://cdn.example.com/locales/prod/manifest.json
```

`dialect init` generates this file with the header comments included. Teams can customize the AI Instructions block to add project-specific conventions (tone, formality, domain-specific rules) without creating additional files.

For highly complex projects that outgrow YAML comments (e.g., detailed style guides with examples per locale), teams can optionally add a `dialect/CONVENTIONS.md` and reference it from the header: `#   - See dialect/CONVENTIONS.md for extended style guide`. This is not generated by default.

### Platform Formats

**Shipping or planned for v1.0–v1.2:**

| Format | Key Style | Pluralization | Used By | Status |
|---|---|---|---|---|
| `arb` | `camelCase` (flat) | ICU MessageFormat | Flutter (`flutter gen-l10n`-compatible by design) | v1.0 |
| `icu-json` | `camelCase` (flat) | ICU MessageFormat (preserved) | Backend APIs with ICU runtime | v1.1 |
| `flat-json` | `camelCase` (flat) | None (stripped to `other` branch) | Backend APIs without ICU | v1.1 |
| Bundle (`bundle.md` spec) | manifest + per-locale JSON | Same as the chosen JSON format | `dialect publish` / `dialect pull` / Cloud delivery | v1.2 |

`flat-json` strips ICU pluralization and outputs plain interpolation strings — use it for backends that only need simple key-value lookups. `icu-json` preserves the full ICU MessageFormat expressions — use it for backends that parse ICU strings at runtime with a library like `intl-messageformat` (Node), `icu4c` (Python), or `MessageFormat` (C#). See [Backend Platforms](platforms-backend.md) for details.

**Stable JSON contract.** The `icu-json` and `flat-json` output shapes are versioned and specified in `dialect/spec/icu-json.md` / `dialect/spec/flat-json.md`. Backend localizer libraries (the `Dialect.AspNetCore` NuGet package, community packages, hand-written snippets) target this contract. Breaking changes to the JSON shape require a major version bump.

### Not on the roadmap as adapters

The following are **explicitly out of scope.** See [`roadmap.md`](roadmap.md) for the full list.

- **`apple-strings` / `.stringsdict` (iOS native)** and **`android-xml` / `<plurals>` (Android native).** Flutter generates iOS/Android-compatible output from `AppLocalizations` via its own build; native string files matter only for edge cases (method channels, native plugins, launch screens). For those, document the gap and let users hand-write the small native files they need. The maintenance cost of two adapters outweighs the value for the Flutter-led ICP.
- **`.resx` (ASP.NET)** and **`.po` (gettext)**. Both would require silently degrading ARB features — `.resx` has no native ICU plurals and uses positional `{0}` placeholders; `.po` has the 2-form / 6-form `ngettext` awkwardness. Instead, Dialect ships **lossless drop-in localizer templates** for each stack: the `Dialect.AspNetCore` NuGet for ASP.NET, a JSON catalog swap for Django, equivalent loaders for Flask/FastAPI/Node/Go. Callsites stay unchanged; only the backing store swaps to Dialect's `icu-json`. See [Backend Platforms](platforms-backend.md). The principle is **Backend Humility**: your backend keeps its native localization interface, Dialect just swaps the backing store.
- **`i18next-json` for React / React Native.** Originally planned for v1.4; deprioritized in 2026-05 alongside iOS/Android adapters. React-web-only teams are not the ICP — `i18next` alone covers their needs without Dialect.

---

## Glossary: `glossary.yaml`

Define project-specific terms so AI translations stay consistent:

```yaml
terms:
  - term: "Book"
    meaning: "To make a reservation (verb), NOT a physical book"
    translations:
      es: "Reservar"
      ja: "予約する"
      ar: "احجز"

  - term: "Host"
    meaning: "A person who lists their property, NOT a computer server"
    translations:
      es: "Anfitrión"
      ja: "ホスト"

style:
  tone: "friendly, concise"
  formality:
    es: "tú (informal)"
    de: "Sie (formal)"
    ja: "です/ます (polite)"
```

---

## Namespaces

Not every string is shared across platforms. The `@key.namespace` metadata controls which strings sync to which platform:

```json
{
  "@@locale": "en",
  "commonLoading": "Loading...",
  "@commonLoading": { "namespace": "common", "description": "Shared across all platforms" },

  "mobilePullToRefresh": "Pull to refresh",
  "@mobilePullToRefresh": { "namespace": "mobile", "description": "Mobile only — Flutter and React Native" },

  "webCookieConsent": "We use cookies to improve your experience",
  "@webCookieConsent": { "namespace": "web", "description": "Web only — React" },

  "backendErrorRateLimit": "Too many requests. Try again in {seconds} seconds.",
  "@backendErrorRateLimit": { "namespace": "backend", "description": "API rate limit response" }
}
```

Configure which namespaces sync to which platform:

```yaml
platforms:
  flutter:
    namespaces: [common, mobile]
  ios:
    namespaces: [common, mobile]
  android:
    namespaces: [common, mobile]
  backend:
    namespaces: [common, backend]
```

---

## Split-File Architecture

For large projects, split source strings by feature to reduce merge conflicts:

```
dialect/source/
  features/
    checkout_en.arb
    settings_en.arb
    profile_en.arb
```

`dialect sync` merges these before generating platform outputs, maintaining key uniqueness across files.

---

## Review UI

`dialect serve` provides a local web interface for non-developers to review and edit translations. **Ships in v1.0** — the dashboard is the visual "wow" of the demo, not a later addition. A Svelte SPA is embedded as static assets in the CLI binary, served by a Dart Shelf server on `localhost:4077`. No `npm install`, no hosting, no accounts.

### When to Use It

- A native speaker flags a translation as culturally wrong for a specific market
- Legal requires specific wording in a regulated locale
- A PM wants to tweak CTA copy without filing a dev ticket
- User feedback reports a confusing translation that needs a quick fix
- A new market requires brand-specific terminology that differs from the "correct" translation

### How It Works

A Dart Shelf server on localhost serves a static SPA that talks to a REST API backed by the local `dialect/` directory. No hosting, no accounts, no third-party service.

```bash
$ dialect serve
Dialect Review running at http://localhost:4077
Reading from: ./dialect/
```

The UI shows:

- Translation table with source language and a selectable target locale side-by-side
- `@key` descriptions displayed as context for each string
- Glossary terms highlighted when they appear
- Filters by: missing translations, namespace, feature file
- Search by key name or string content
- Inline editing with save-to-file
- Pin/lock to mark a translation as human-approved (prevents `dialect translate` from overwriting it)

### REST API

The local server exposes a small API that the SPA consumes:

| Endpoint | Method | Description |
|---|---|---|
| `/api/config` | GET | Returns `dialect.yaml` contents (locales, platforms) |
| `/api/strings?locale=es` | GET | All strings with source, target, and metadata |
| `/api/strings/:key` | PUT | Update a translation for a specific locale |
| `/api/glossary` | GET | Glossary terms and style guide |
| `/api/status` | GET | Coverage stats per locale |

The SPA is embedded as static assets in the CLI binary. No npm install, no build step. Just `dialect serve`.

---

## CI Integration

Add `dialect check` to your CI pipeline:

```yaml
# .github/workflows/dialect.yml
name: Dialect Check
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate dialect
      - run: dialect check --strict
      - run: dialect diff --format markdown >> $GITHUB_STEP_SUMMARY
```

PRs that break translations don't merge.
