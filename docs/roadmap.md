# Roadmap

> **Last updated: 2026-05-25.** This is the public roadmap. Items past v1.0 are planned, not shipped. The phased plan reflects current direction; specifics may shift as v1.1 and v1.2 land and dogfood feedback surfaces.

## Shipped — v1.0

- `dialect init` — scaffold + AI-pointer init plan
- `dialect import`, `dialect describe`, `dialect translate` — AI-pointer flows for semantic work
- `dialect sync` — Flutter ARB output (canonical → `lib/l10n/`)
- `dialect check` — structural + semantic validation, soft mode + `--strict`
- `dialect status` — coverage snapshot
- `dialect serve` — local web UI on `localhost:4077`
- Distribution: pre-built binaries (curl installer + Homebrew tap), Pub global, GitHub Action
- Stable on-disk contracts: [`icu-json`](../dialect/spec/icu-json.md), [`flat-json`](../dialect/spec/flat-json.md), [`@key.source_hash`](../dialect/spec/source_hash.md), [`.dialect/state.json`](../dialect/spec/state.md)

## v1.1 — Backend sync + sync DX

> **Status (in progress on `main`, pre-release):** the backend adapters and the
> `dialect translate` work-list flow are implemented and tested; the remaining
> v1.1 items (`Dialect.AspNetCore`, `serve` auto-resync, `--watch`/`--dry-run`)
> are still open.

- **Backend adapters land:** `icu-json` and `flat-json` formats fully implemented (specs already locked in v1.0). ✅ *Done — `dialect sync` emits `<locale>.json`; `flat-json` collapses ICU to the `other` branch and prints a lossy-event hint.*
- **Backend consumption is documented snippets, not packages.** Every stack (ASP.NET, Django, Flask/FastAPI, Node, Go) consumes `icu-json` via a small lossless snippet — see [`platforms-backend.md`](platforms-backend.md). The ASP.NET `JsonStringLocalizer` keeps `IStringLocalizer<T>` callsites unchanged in ~30 lines.
- **`Dialect.AspNetCore` NuGet — nice-to-have, not release-blocking.** A polished package that wraps the documented `JsonStringLocalizer` behind `dotnet add package` + `AddDialectLocalization(...)`. Pure install ergonomics; the snippet is already complete, so this ships later if demand justifies it. (Same for a `BundleUrl`-at-startup option in v1.2.)
- **`dialect serve` auto-resync** — dashboard edits trigger sync automatically, push diff over websocket
- **Sync CLI ergonomics:** `--dry-run`, `--platform <name>` ✅ *done*; `--watch` and an end-of-run lossy-event summary still open
- **Scope cut:** `apple-strings` and `android-xml` adapters are **dropped from the roadmap**. The actual Flutter ICP doesn't maintain iOS/Android native string files as separate dev surfaces; Flutter's own build generates iOS/Android-compatible output. For edge cases (method channel callbacks, launch screens, native plugins), document the gap and link to Flutter's `gen-l10n` for the in-Flutter approach.

## v1.2 — Bundle format + `dialect publish`

- **Bundle format spec** at [`dialect/spec/bundle.md`](../dialect/spec/) — manifest.json + per-locale JSON files, immutable content-hashed versions
- **`dialect publish <env>`** — builds bundle and uploads to a user-configured target. Ship two targets: `local` (filesystem) and `s3` (S3-compatible, covers R2/MinIO/Cloudflare R2). Same protocol Cloud will use.
- **`dialect pull`** — companion command that fetches the latest bundle and writes into `dialect/translations/`. Used in CI deploy scripts.
- **`BundleUrl`-at-startup** (via the nice-to-have `Dialect.AspNetCore` package, or a documented snippet) — read manifest + locale JSONs at app startup, with `wwwroot/locales` fallback. No background poller — `dialect pull` + redeploy is the live-update mechanism.
- Snippet docs for Node / Go / Python / Django — same "fetch on startup, optional `dialect pull` in deploy script" pattern.

## v1.3 — Dialect Cloud MVP

A managed instance of `dialect-server` running at **dialect.tools**. See [`docs/cloud.md`](cloud.md) for the full picture.

- **Hosted dashboard** at `dialect.tools` — translators edit AI-generated translations without learning git
- **GitHub OAuth** for sign-in (devs); magic-link email comes after MVP
- **`dialect login`, `dialect link`, `dialect push`, `dialect pull`** — CLI commands that talk to Cloud (and to self-host via `--server <url>`)
- **Push/pull REST API** on `dialect-server`
- **Server-side `publish`** — Cloud builds the bundle and uploads to its Cloudflare R2 CDN; returns a manifest URL
- **`dialect export`** — full project tarball anytime, for migration to self-host or back to local files

What's intentionally **out of MVP**:
- Multiple environments per project (single env only at first)
- Team invites / multi-user-per-project
- Translation status flags beyond the basics
- Webhooks
- Magic-link email (GitHub OAuth covers the dogfood audience)

## v1.4 — Self-host packaging (community OSS)

The same `dialect-server` binary that runs Cloud, packaged for users who want to run their own infra. **Free, OSS, community-supported — there is no paid self-host tier and no managed support SLA.**

- **Docker image** and `docker-compose.yml` (server + Postgres + MinIO for S3-compatible storage)
- **Connection-strings doc** showing how to point self-host at your own Postgres, your own S3-compatible bucket
- **Migration tooling** — `dialect export` from Cloud → `dialect import` into self-host (and vice versa)
- Same protocol as Cloud, so CLIs and backend libraries don't care which one they're talking to

Self-host exists as a trust anchor (Cloud users can leave anytime) and as an option for teams who genuinely prefer owning the infra. It is not a managed product. There are no Pro features locked behind a self-host license key.

## v1.5+ — AI-review affordances + polish

- **Translation confidence indicators** in the dashboard (single-shot AI vs. AI-with-context vs. human-edited)
- **"Re-translate with newer model"** action per key/locale
- **Stale-flag dashboard view** — when source English changes, surface affected translations for review
- **`dialect diff`** — Markdown changes summary for PR comments
- **`dialect merge`** — key-aware ARB merge driver for git conflicts (opt-in via `dialect init --enable-merge-driver`)

## v2.0+ — Long-tail

- **Flutter OTA** via the `dialect_ota` package — same bundle format as v1.2, different client (offline layering, app-store bypass framing). Reuses the publish pipeline.
- **Multi-environment publishing** — `dialect publish staging`, `dialect publish prod`
- **Sponsored adapters** for native iOS / Android / React / Vue / Svelte / etc., if community demand and contribution capacity materialize. Mechanical conversion from ARB to each target's format; the architecture supports them, the work is bounded.
- **Translation memory** if real-user signal asks for it

---

## What's not on the roadmap, by design

The list below is *deliberately* not built. Every item failed a deliberate filter — either it requires features incompatible with the convention, it serves <5% of users at high maintenance cost, or it would force active sales motion incompatible with Dialect's indie-passive business model.

- **SSO / SAML, audit log, RBAC, team management beyond per-project membership.** Enterprise compliance features. Roughly 2–5% of users would benefit; building them well takes months. If your team needs these, Lokalise / Phrase / Smartling already cover them well — Dialect isn't trying to compete there.
- **Multi-region deployment, custom branding / white-label, sub-second update SLA, dedicated support contracts.** Same reasoning — enterprise features incompatible with self-serve indie SaaS.
- **`dialect-server` paid tier or license-key-activated features.** Self-host is community OSS, full stop. There is no managed self-host product.
- **"Contact Sales" pricing tier.** Public pricing only. No custom contracts.
- **Consulting / migration services as a productized revenue line.** One-off paid help for friends-of-the-project is fine; running it as a service is not.


- **`.resx` adapter (ASP.NET).** Lossy. We ship the `Dialect.AspNetCore` NuGet package consuming `icu-json` instead. See [Backend Humility](platforms-backend.md#the-principle-backend-humility).
- **gettext `.po` adapter.** Same reasoning. We document the JSON catalog swap for Django/Babel.
- **Native iOS `.strings` / Android `strings.xml` adapters.** Dropped — see v1.1 notes above.
- **Dialect calling LLM APIs as the default for semantic work.** AI-pointer flow is primary; `dialect translate --auto` is a CI convenience. Always BYO LLM key — Dialect doesn't resell inference.
- **Dotted-key conventions.** Flat camelCase + `@key.namespace` metadata is required by Flutter's `gen-l10n`. We don't reintroduce dots.
- **Bidirectional sync from generated files back to source.** Source ARB is the single source of truth; sync is one-way.
- **Dialect having its own auto-translation models or hosting LLM infrastructure.** AI is the user's responsibility (or `--auto` with their own key).

---

## See also

- [Why Dialect](thesis.md) — the problem and the insight
- [Architecture](architecture.md) — current CLI reference and convention
- [Dialect Cloud](cloud.md) — what Cloud + self-host look like
