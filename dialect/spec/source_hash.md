# `@key.source_hash` — Source-Value Fingerprint Spec

**Status:** v1.0. Stable contract; breaking changes require a major-version bump and a migration note.

**Owners:** `dialect status` (M6 — reads), the dashboard's pin/lock action (M10 — writes), `dialect translate` (M8 — reads to decide whether to skip locked entries).

---

## What it is

`@key.source_hash` is a small, stable fingerprint of a translation key's canonical English value. When a translator pins ("locks") a target translation, the dashboard captures the fingerprint of the **source** at lock-time and writes it onto the translation's `@key` block. Later, if the source value changes, the hash mismatch tells everyone the locked translation is now **stale** — the human reviewer pinned a translation of an older English string, and the new English needs a fresh review.

The field lives on the **translation** ARB (`dialect/translations/<locale>.arb`), inside each `@key` block. It does **not** appear on the source ARB itself — the source IS the canonical value, comparing it to itself is meaningless.

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
| Written by | The dashboard (M10) at pin/lock-time |
| Read by | `dialect status` (M6), the dashboard's stale indicator, `dialect translate --skip-locked` logic (M8+) |

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

A translation ARB with **no** `source_hash` on a locked entry is **not** a stale entry — it's a pre-spec lock from before the dashboard knew to write the field. `dialect status` reports it as "locked, no hash" (a soft state, not flagged), and the dashboard fills in the hash on the next interaction. We never invalidate user-pinned translations because their hashes are missing.

Unlocked entries never carry `source_hash` (no lock-time, no fingerprint).

---

## Out of scope for v1.0

- Hashing across multiple sources (multi-source-ARB projects don't exist in v1.0).
- Hashing the rendered ICU output rather than the template — too brittle across plural-category sets.
- A separate `@key.glossary_hash` for glossary-coupled invalidation — interesting for v1.1+ if real users hit it, but premature now.
- Migrating between hash algorithms — when we eventually need it, the field becomes `source_hash: "sha256-16:a3deb…"` so old and new can coexist. Out of scope for v1.0.
