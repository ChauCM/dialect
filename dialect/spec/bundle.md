# `dialect-bundle/1` — Published Translation Bundle Spec

**Status:** v1.2. Stable contract. Breaking changes require a major-version bump of the `schema` string (`dialect-bundle/2`) and a migration note in `CHANGELOG.md`.

**Owners:** `dialect publish` (writes), `dialect pull` (reads), backend localizer snippets / the nice-to-have `Dialect.AspNetCore` package (read a manifest URL at startup), Dialect Cloud v1.3 (publishes the same shape to its R2 CDN).

---

## What it is

A **bundle** is an immutable, content-addressed snapshot of a project's translations for one *environment* (e.g. `production`, `staging`). `dialect publish <env>` builds a bundle from the canonical ARBs — in the platform's chosen JSON format ([`icu-json`](./icu-json.md) or [`flat-json`](./flat-json.md)) — and uploads it to a user-configured target (filesystem, S3/R2, …). A backend reads the bundle's manifest URL at startup, or `dialect pull <env>` fetches it into a deploy artifact in CI.

The bundle is the **live-update mechanism**: there is no background poller. A new publish produces a new immutable version; consumers pick it up on their next startup / `dialect pull` + redeploy. Immutability makes every file infinitely CDN-cacheable, which is load-bearing for Cloud's zero-egress economics.

The protocol is identical across every target and across local-only, self-host, and Cloud — only the transport (filesystem write vs. S3 PUT vs. server endpoint) differs.

---

## Layout

A bundle lives under a target **prefix** (a directory, an S3 key prefix, …):

```
<prefix>/
  manifest.json                       # channel head — the mutable entry point
  b/<bundle_version>/
    manifest.json                     # immutable bundle manifest
    en.json                           # immutable per-locale files
    es.json
    …
```

- **`<prefix>/manifest.json` — the channel head.** The only mutable object. A consumer always fetches this first to discover the current version. Overwritten on every publish; tiny, so a stale CDN copy self-heals in one TTL.
- **`b/<bundle_version>/…` — the immutable bundle.** Everything under a content-addressed version directory never changes. Safe to cache forever (`Cache-Control: immutable`). Re-publishing identical content reuses the same `<bundle_version>` directory — the upload is a no-op.

---

## The channel head (`<prefix>/manifest.json`)

```json
{
  "schema": "dialect-bundle/1",
  "current": "8f3a1c0b9d2e4f67",
  "manifest": "b/8f3a1c0b9d2e4f67/manifest.json"
}
```

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | Always `dialect-bundle/1` in v1.2. |
| `current` | string | The `bundle_version` of the currently-published bundle. |
| `manifest` | string | Prefix-relative path to the immutable bundle manifest. |

A consumer compares `current` against the version it last loaded to decide whether anything changed — that is the entire "did translations update?" check. No diffing, no polling.

---

## The bundle manifest (`b/<bundle_version>/manifest.json`)

Immutable and self-contained — given just this file a consumer can fetch and verify every locale.

```json
{
  "schema": "dialect-bundle/1",
  "bundle_version": "8f3a1c0b9d2e4f67",
  "format": "icu-json",
  "source_locale": "en",
  "locales": [
    { "locale": "en", "file": "en.json", "sha256": "9f86d0818884…", "keys": 247 },
    { "locale": "es", "file": "es.json", "sha256": "2c26b46b68ff…", "keys": 247 }
  ],
  "created_at": "2026-05-30T14:00:00Z",
  "generator": "dialect 1.2.0"
}
```

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | `dialect-bundle/1`. |
| `bundle_version` | string | Content-addressed id — see "Version derivation". Matches the directory name and the channel head's `current`. |
| `format` | string | `icu-json` or `flat-json` — the shape of every locale file in this bundle. |
| `source_locale` | string | The source locale tag (e.g. `en`). |
| `locales` | array | One entry per locale, sorted by `locale`. |
| `locales[].locale` | string | BCP-47 tag. |
| `locales[].file` | string | Manifest-relative filename, always `<locale>.json`. |
| `locales[].sha256` | string | Full lowercase-hex SHA-256 of the locale file's exact bytes. Integrity + cache key. |
| `locales[].keys` | int | Number of keys in the file. Informational (sanity check / dashboards). |
| `created_at` | string | ISO-8601 UTC publish time. **Informational only** — not an input to `bundle_version`, so re-publishing identical content is deterministic. |
| `generator` | string | `dialect <version>` that built the bundle. Informational. |

### Per-locale files (`b/<bundle_version>/<locale>.json`)

Byte-identical to what `dialect sync` would emit for that platform: a flat JSON object in the manifest's `format`, 2-space indent, LF, trailing newline, keys sorted. The `sha256` in the manifest is over these exact bytes. See [`icu-json`](./icu-json.md) / [`flat-json`](./flat-json.md).

---

## Version derivation

`bundle_version` is a deterministic function of **content only**, so identical translations always yield the same version (idempotent publish, free dedup):

```
bundle_version = sha256-16( canonical )
canonical      = "dialect-bundle/1\n"
               + "format:"  + format        + "\n"
               + "source:"  + source_locale + "\n"
               + for each locale sorted by tag:
                   locale + " " + <locale file sha256> + "\n"
```

`sha256-16` is SHA-256 truncated to the first 16 lowercase-hex chars, matching [`@key.source_hash`](./source_hash.md). `created_at` and `generator` are deliberately excluded — a publish with no translation changes produces the same `bundle_version` and re-uploads nothing.

---

## `dialect publish <env>`

1. Load the project; resolve `publish.<env>` from `dialect.yaml` (see "Config").
2. Build each locale file in the configured `format` (same encoder as `dialect sync`), compute its SHA-256, count keys.
3. Derive `bundle_version`; assemble the bundle manifest.
4. Upload `b/<bundle_version>/manifest.json` + each `<locale>.json` to the target **if not already present** (immutable — existing objects are never overwritten).
5. Overwrite the channel head `<prefix>/manifest.json` to point at the new version. This is the atomic "go live" step — it is written **last**, after every immutable object is in place, so a consumer never sees a head pointing at an incomplete bundle.

`--dry-run` performs steps 1–3 and prints what would upload without writing.

## `dialect pull [<env>]`

1. Fetch the channel head `manifest.json` (from the target, or a configured `manifest_url`).
2. Fetch the bundle manifest it points at.
3. For each locale, fetch `<locale>.json`, **verify its bytes against the manifest `sha256`** (abort on mismatch — a corrupt or truncated CDN object must never reach production), and write it to the env's `output` directory.
4. Print the `bundle_version` pulled and the per-locale key counts.

`pull` is for CI deploy scripts: fetch the latest published translations into the build, then deploy. It writes the per-locale JSON consumed by the backend — it does **not** touch the canonical ARBs in `dialect/source` / `dialect/translations` (the source of truth is upstream of a published bundle, never derived back from one).

---

## Config: `publish` in `dialect.yaml`

```yaml
publish:
  production:
    target: s3                 # local | s3
    bucket: my-bucket
    prefix: locales/prod/
    format: icu-json           # optional; defaults to the bundle format below
    manifest_url: https://cdn.example.com/locales/prod/manifest.json   # for pull
    output: api/locales/       # where `dialect pull` writes locale files
  staging:
    target: local
    path: dist/locales/staging/   # prefix on the local filesystem
    output: api/locales/
```

| Key | Targets | Meaning |
|---|---|---|
| `target` | all | `local` (filesystem) or `s3` (S3-compatible: AWS S3, Cloudflare R2, MinIO). |
| `path` | `local` | Filesystem prefix the bundle is written under. |
| `bucket` / `prefix` | `s3` | Bucket and key prefix. Credentials come from the standard AWS env vars / `~/.aws`, never from `dialect.yaml`. |
| `format` | all | `icu-json` or `flat-json` for this environment's bundle. |
| `manifest_url` | all | Public URL of the channel head, used by `dialect pull` and by backends reading at startup. |
| `output` | all | Directory `dialect pull` writes the fetched locale files into. |

---

## Worked example (`target: local`)

```
$ dialect publish staging
✓ built bundle 8f3a1c0b9d2e4f67 (icu-json, 2 locales, 247 keys)
  wrote dist/locales/staging/b/8f3a1c0b9d2e4f67/manifest.json
  wrote dist/locales/staging/b/8f3a1c0b9d2e4f67/en.json
  wrote dist/locales/staging/b/8f3a1c0b9d2e4f67/es.json
  updated dist/locales/staging/manifest.json → 8f3a1c0b9d2e4f67

$ dialect publish staging          # no translation changes
✓ bundle 8f3a1c0b9d2e4f67 already published — nothing to upload.

$ dialect pull staging
✓ pulled 8f3a1c0b9d2e4f67 → api/locales/  (en: 247, es: 247)
```

---

## Out of scope for v1.2

- **Partial / incremental bundles.** A bundle always contains every locale. Per-locale delta sync is a v2.0+ concern (the Flutter OTA path reuses this format).
- **Signed bundles / provenance attestation.** SHA-256 gives integrity, not authenticity. Signing is deferred until a concrete threat model asks for it.
- **Bundle GC / retention.** Old `b/<version>/` directories accumulate; pruning them is the operator's choice. Dialect does not delete remote objects.
- **A background poller.** Out of scope by design — `dialect pull` + redeploy, or a webhook → reload endpoint (see `docs/platforms-backend.md`), is the update path.
- **Compression / binary encoding.** Plain JSON; the CDN handles gzip/br on the wire.
