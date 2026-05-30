# Dialect Cloud

> **Status: Planned for v1.3.** Cloud is the next major milestone after backend sync (v1.1) and the bundle format / `dialect publish` (v1.2). This doc describes the shipping target; nothing here is live yet.

Dialect Cloud is a managed instance of `dialect-server` running at **dialect.tools**. It exists so non-developer translators can review and edit AI-generated translations without learning git, and so backends can fetch the latest translation bundle from a hosted URL.

The CLI is, and will remain, **forever free and full-featured**. Cloud monetizes managed-ness and collaboration only — never features that belong in the dev toolchain.

---

## Three modes of running Dialect

Pick the one that fits your team. All three speak the same protocol; you can switch between them.

| | **Dialect Cloud** | **Self-Host** | **OSS local-only** |
|---|---|---|---|
| Translation values stored in | Cloud's Postgres | Your Postgres | Your git repo (`dialect/translations/*.arb`) |
| Editing UI | `dialect.tools` (hosted) | `your-domain.com` (your `dialect-server` instance) | `dialect serve` on `localhost:4077` |
| Schema (source ARB + metadata) | Your git, pushed via `dialect push` | Your git, pushed via `dialect push` | Your git only |
| Bundle delivery | Cloud-hosted CDN (or your S3) | Your S3 / CDN | Your S3 / CDN |
| Setup cost | Sign in with GitHub | Run `docker compose up` | None — already works today |
| Multi-user / translator UI | Yes | Yes | No (single-user local UI) |
| Lock-in | None — `dialect export` produces a clean tarball anytime | None — your infra | None — your files |

OSS local-only is what ships today. Cloud and self-host arrive at v1.3 and v1.4 respectively.

---

## The Cloud workflow

The clean conceptual split: **devs own the schema; translators own the values.**

### Developer side (with AI agent)

1. AI agent adds new keys to `dialect/source/en.arb` and generates initial translations into `dialect/translations/*.arb` in the same turn.
2. AI runs `dialect push` — keys, source values, and AI-generated translations are sent up to Cloud.
3. AI runs `dialect publish prod` — Cloud builds the bundle and uploads to its CDN; returns a manifest URL.
4. Dev commits the source ARB + Flutter code. Backend deploys; reads the manifest URL at startup.

The dev never opens the Cloud dashboard. Their interface is git + the AI agent.

### Translator side (no git, no terminal)

1. Translator opens `dialect.tools`, logs in with GitHub or magic-link email.
2. Sees the project board: keys × locales, with status flags (AI-generated unreviewed, approved, human-edited, stale).
3. Reviews AI-generated translations, edits where needed, approves the rest.
4. Hits "publish" — Cloud rebuilds the bundle and pushes to its CDN.

**Note:** Translations are never "missing" — every key already has an AI-generated value by the time it reaches Cloud. The translator's role is review, not initial drafting.

### Sync back to local

When the dev wants the latest translations in their repo (for a build, for AI agent context, or just to commit them):

```bash
dialect pull
```

Writes the current Cloud state into `dialect/translations/*.arb`. Some teams gitignore the translation files since they're regenerable from Cloud; others commit them as a backup.

---

## Backend integration

Backends fetch the bundle at startup. No background poller — `dialect pull` and redeploy is the live-update mechanism.

```csharp
// ASP.NET
builder.Services.AddDialectLocalization(opts =>
{
    opts.BundleUrl = "https://cdn.dialect.tools/p/my-app/manifest.json";
    opts.Fallback  = "wwwroot/locales";  // bundled at build time
});
```

The `Fallback` directory is read if the bundle URL is unreachable at boot. Run `dialect pull` in your deploy script to keep `wwwroot/locales` fresh as a backup.

For other stacks (Node, Go, Python, Django), the snippet docs in [`platforms-backend.md`](platforms-backend.md) show the equivalent pattern — fetch the bundle URL at startup, fall back to local files.

---

## Lock-in escape

The data your team puts into Cloud should be portable without our help. At any time:

```bash
dialect export --project my-app --out my-app.tar.gz
```

Produces a tarball with all keys, source values, translations, metadata, and history. Restore into self-host, into another Cloud project, or back into your git repo. No "premium export" tier, no rate limit, no support ticket required.

This is the trust anchor for Cloud adoption. The CLI is forever free; the data is forever yours.

---

## When to use Cloud vs. self-host vs. OSS local-only

**Use OSS local-only (today)** if:
- You're a small Flutter team where everyone has git access
- Translators are dev-adjacent or use AI themselves
- You don't need a hosted dashboard
- You're fine running `dialect publish` to your own S3 / R2 / git bucket

**Use Dialect Cloud (v1.3+)** if:
- Non-dev translators or PMs need to edit translations
- You want hosted bundle delivery without operating S3/R2 yourself
- You want zero infra commitment to start

**Use self-host (v1.4+)** if:
- Compliance or data-residency requires on-prem
- You prefer to own the infra outright
- You're comfortable running it as community OSS (no managed support, no SLA — see Pricing below)

Migration between modes is `dialect export` + `dialect import` — one command in each direction.

---

## Pricing

Three tiers, public prices, self-serve checkout. No "talk to sales."

| Tier | Price | What's included |
|---|---|---|
| **Free** | $0 forever | 1 project, ≤5 locales, ≤500 keys, 1 owner, public bundles, BYO LLM key |
| **Pro** | **$15 / month per project** | Unlimited locales/keys, up to 5 invited reviewers (magic-link), private bundles (signed URLs), email digests, webhook on publish, BYO LLM key |
| **Team** | **$49 / month per account** | Up to 5 projects, unlimited reviewers across them, cross-project glossary sharing, optional managed AI translation credits at cost-pass-through |

`dialect translate --auto` is **BYO LLM key** by default — Dialect never resells inference, so there's no provider lock-in and no vendor margin baked into pricing. Team tier optionally offers managed credits at cost-pass-through for non-technical owners who don't want to set up Anthropic / OpenAI accounts.

**Self-host is free, forever.** The same `dialect-server` binary that runs Cloud. Run it on your own Postgres + S3-compatible storage. There is no paid self-host tier and no Pro features locked behind a license key — self-host is a community OSS option, not a managed product. If you need on-prem deployment with a support SLA, you'll be happier on Lokalise or Phrase; that's not what Dialect sells.

---

## See also

- [Roadmap](roadmap.md) — when Cloud and self-host are landing
- [Architecture](architecture.md) — the CLI commands (`push`, `pull`, `publish`, `login`, `link`) that talk to Cloud
- [Backend Platforms](platforms-backend.md) — how each backend stack consumes the bundle URL
