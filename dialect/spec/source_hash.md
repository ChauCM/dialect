# `@key.source_hash` — Source-Value Fingerprint Spec

**Status:** v1.0. Stable contract; breaking changes require a major-version bump and a migration note.

**Owners:** `dialect check --fix` (**writes** — stamps unlocked translations), the dashboard's pin/lock action (**writes** — stamps at lock-time), `dialect status` / `dialect check`'s `stale_translation` rule / `dialect translate` (**read** — compute staleness).

---

## What it is

`@key.source_hash` is a small, stable fingerprint of a translation key's canonical English value, recorded **on the translation** to mark which source version it was written against. It is the provenance behind staleness detection: if the English source later changes, the stored hash no longer matches the current source's hash, and the translation is **stale** — it needs re-translating (or re-reviewing).

Every translation carries it — not only locked ones:

- **`dialect check --fix`** stamps the current source hash onto any *unlocked* translation that has a value but no hash (new translations, or values just written by an AI / `dialect pull`). It never overwrites an existing hash, so a stale translation stays stale until it is actually re-translated.
- **The dashboard** stamps it at lock-time (and on edit), the same way.

The field lives on the **translation** ARB (`dialect/translations/<locale>.arb`), inside each `@key` block. It does **not** appear on the source ARB itself — the source IS the canonical value, comparing it to itself is meaningless.

This is also the Cloud (v1.3) contract: in Cloud the same hash is a column on the translation row in Postgres, carried by `push`/`pull` alongside the value. The staleness definition (`stored ≠ current source hash`) is identical across local-only, self-host, and Cloud — provenance travels with the value wherever the value lives.

---

## Specification

| Decision | Value |
|---|---|
| Algorithm | SHA-256 |
| Output length | First 16 hex chars (64 bits) of the digest |
| Encoding | Lowercase hex, no `0x` prefix |
| Input | NFC-normalized source value string only |
| **NOT** hashed | description, context, placeholders, source_hash itself, any other `@key.*` field |
| Field name | `source_hash` (snake_case to match the rest of `@key.*`) |
| ARB type | string |
| Written by | `dialect check --fix` (unlocked translations, stamp-if-missing); the dashboard at lock/edit-time |
| Read by | `dialect status`, the `stale_translation` check rule, `dialect translate`, the dashboard's stale indicator |
| Stamp rule | `--fix` stamps current hash onto an unlocked entry with a value and no hash. Existing hashes are never overwritten (staleness survives until re-translation clears the hash). Locked entries are stamped only by the lock flow, never by `--fix`. |

### Rationale for the choices

- **SHA-256 truncated to 16 hex chars.** A 64-bit fingerprint has ≈ 18 trillion buckets; collision risk between any two real-world ARB values is effectively zero for project-scale string sets (millions of keys). Truncating keeps the on-disk ARB readable — 64 chars per `@key` block would dominate the file. We use SHA-256 (not MD5 or CRC32) so the field reads as a "real" cryptographic-grade hash to anyone scanning the file, even though we don't need cryptographic properties.
- **Lowercase hex, no prefix.** Matches `git`'s short-SHA convention. Easy to compare by eye, trivial to copy-paste.
- **Source value string only.** Rewriting a description or adjusting placeholder type metadata should **not** invalidate a human-reviewed translation. Only a change to the user-facing English text invalidates the lock. Placeholder-name mismatches are caught by the M4 `placeholder_match` structural rule, not by the hash.
- **NFC normalization.** The parser NFC-normalizes every string on read (M2). Hashing the post-NFC value means a source typed on macOS (NFD by default) and the same source typed on Linux (NFC by default) hash identically.

---

## Worked example

```text
Source ARB (en.arb):
  "checkout.bookNow": "Book Now"

Compute:
  SHA-256("Book Now") =
    67be79359de4aa3f… (full 64 hex chars)
  Truncate to 16:
    67be79359de4aa3f

Dashboard lock-time write into es.arb:
  "checkout.bookNow": "Reservar ahora",
  "@checkout.bookNow": {
    "locked": true,
    "source_hash": "67be79359de4aa3f"
  }

Later, source changes:
  "checkout.bookNow": "Book this stay"

`dialect status` recomputes:
  SHA-256("Book this stay")[0:16] ≠ 67be79359de4aa3f
  → stale count for `es` increments by 1.
```

---

## Backward compatibility

A translation entry with **no** `source_hash` is **untracked**, not stale — its provenance is simply unknown. This is the adoption path: an existing project's translations carry no hash until the first `dialect check --fix` stamps them. Until then `status`/`check` never flag them, so turning the feature on doesn't flood a project with false positives. The first `--fix` baselines every unlocked translation as fresh-against-current (the usual case for committed translations); tracking is exact from there forward.

A locked entry with no `source_hash` is likewise untracked (a pre-spec lock) — `locked` but not flagged. The lock flow fills the hash on the next interaction; we never invalidate a user-pinned translation just because its hash is missing.

---

## Why hashes live in the ARB, not a sidecar

**Decision: hashes stay inline in the `@key` block. Rejected: a sidecar file** (e.g. `dialect/translations/.vi.hashes.json`).

The cost of inline is real and lands at one specific moment. A hand-authored locale starts as ~280 reviewable lines of flat `"key": "value"` pairs; the first `check --fix` stamps every key and the file becomes ~1,300 lines, because each key gains a three-line `@key` block. That is a diff no human can meaningfully review, on the one file whose *content* most deserves review — the first pass of a new language.

A sidecar would keep that diff small, and was rejected anyway:

- **The ARB stops being self-describing.** Today a translation file carries its own provenance; anyone can read one file and know whether an entry is tracked, locked, and current. Splitting that puts half the truth somewhere else.
- **Two files that must agree about the same key set is a drift bug waiting to happen.** Rename a key, hand-edit a value, resolve a merge conflict in one file but not the other — and the hashes now describe a state that never existed. Staleness detection is exactly the feature that must not silently lie.
- **It is a permanent cost to avoid a one-time one.** The big diff happens once per locale, on the run *after* the values are written. Sidecar drift is available on every run, forever.

The affordance instead is `dialect check --fix --no-stamp`: normalize formatting on the authoring pass without creating hashes, review the translations as a clean diff, then run a plain `--fix` to stamp. It defers stamping; it never removes an existing hash, and an unstamped entry stays *untracked* (not stale), so the intermediate state is green rather than red.

---

## Out of scope for v1.0

- Hashing across multiple sources (multi-source-ARB projects don't exist in v1.0).
- Hashing the rendered ICU output rather than the template — too brittle across plural-category sets.
- A separate `@key.glossary_hash` for glossary-coupled invalidation — interesting for v1.1+ if real users hit it, but premature now.
- Migrating between hash algorithms — when we eventually need it, the field becomes `source_hash: "sha256-16:a3deb…"` so old and new can coexist. Out of scope for v1.0.
