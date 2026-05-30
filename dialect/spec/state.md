# `.dialect/state.json` — Soft-Mode Acknowledgement Store

**Status:** v1.0. Stable contract. Breaking changes require a major-version bump.

**Owners:** `dialect check` (reads on every run; writes via `dialect check --ack <rule>:<locale>:<key>` — **implemented**), the dashboard (M10+ — reads to render "dismissed" badges).

---

## What it is

`dialect check` runs in two modes: soft (default) and `--strict` (CI). In soft mode, warnings are surfaced but don't fail the exit code; in strict mode they do (with the `length_ratio` carve-out — see M8). A reviewer working through soft-mode output needs a way to say "this warning is intentional, stop showing it" without globally flipping to strict or editing the rule code.

`.dialect/state.json` is that store. It records per-issue acknowledgements keyed by `<rule_name>:<locale>:<translation_key>`, fingerprinted with the source value that was acknowledged. When the source value changes later, the fingerprint mismatches and the warning surfaces again — acknowledgement is **tied to the source state at ack-time**, the same way `@key.source_hash` ties a lock to its source.

`.dialect/` is gitignored by the canonical `dialect init` template — state acknowledgements are workspace-local by design. If a team wants shared acknowledgements, they ungitignore the file; v1.0 does not opine on this.

---

## File layout

Single file at the project root:

```
.dialect/state.json
```

`dialect/` (canonical convention dir) and `.dialect/` (workspace state) are different paths. The dot-prefixed one is ephemeral; the un-prefixed one is the canonical, committed config.

---

## File shape

UTF-8 JSON object with a `version` field and a `checks` map:

```json
{
  "version": 1,
  "checks": {
    "source_equality:vi:settings.emailLabel": {
      "acknowledged": "67be79359de4aa3f",
      "acknowledged_at": "2026-05-22T11:18:00Z",
      "note": "Email stays \"Email\" in Vietnamese — confirmed with linguist."
    },
    "glossary:ar:checkout.yourTripHeader": {
      "acknowledged": "a1b2c3d4e5f60718"
    }
  }
}
```

| Decision | Value |
|---|---|
| Top-level | JSON object. |
| `version` | Integer `1` in v1.0. Increments only on breaking shape changes. |
| `checks` | Object map. Keys are issue identifiers; values are ack records. |
| Encoding | UTF-8, no BOM. |
| Indentation | 2 spaces, LF, trailing newline. |
| Sort order | Keys sorted lexicographically when Dialect writes. |
| Unknown top-level fields | Preserved verbatim by the writer (forward-compat). |

### Issue identifier

`<rule_name>:<locale>:<translation_key>`.

- `rule_name` — the snake_case rule identifier (`source_equality`, `length_ratio`, `untranslated_english`, `glossary`, …). Same string that appears in the check report.
- `locale` — the target locale the issue is in (e.g. `vi`, `ar`). For source-only issues (orphan metadata, source-ARB-level problems), use `source` as the locale slot.
- `translation_key` — the ARB key. May contain dots (`checkout.bookNow`).

The three parts join with `:` literally. Colons do not appear in any of the parts (rule names are snake_case, locales are BCP-47 hyphen-delimited, ARB keys are namespace.camelCase).

### Ack record

| Field | Type | Required | Meaning |
|---|---|---|---|
| `acknowledged` | string | yes | The source-value hash at ack-time. Format: `<rule_name>`-dependent fingerprint, see "Hash semantics" below. |
| `acknowledged_at` | string | no | ISO 8601 UTC timestamp when the ack was created. Informational. |
| `note` | string | no | Reviewer's free-text justification. Surfaced in the check report under the warning. |
| `acknowledged_by` | string | no | Reviewer identity (e.g. git user.email). v1.0 does not require this; the dashboard may fill it. |

Unknown fields inside an ack record are preserved verbatim — forward-compat for v1.0.x additions.

---

## Hash semantics

The `acknowledged` field stores a fingerprint that lets `dialect check` decide whether the acknowledgement still applies. The rule of thumb: if the warning would re-fire because something the reviewer didn't ack changed, the hash must change.

| Rule | What is hashed |
|---|---|
| `source_equality` | SHA-256-16 of the source value (the same algorithm as [`@key.source_hash`](./source_hash.md)). |
| `untranslated_english` | SHA-256-16 of the translation value. The acknowledgement is "yes, I know this string contains 'the' — it's a carryover". If the translation changes, re-check. |
| `glossary` | SHA-256-16 of the source value. The reviewer is saying "yes, this source uses 'Book' in a non-literal sense for this key" — same trigger as `@key.glossary_exempt: true`, but workspace-local. |
| `length_ratio` | SHA-256-16 of the translation value. Translations that drift further out of band on edit should re-trigger. |
| Structural rules (`missing_keys`, `placeholder_match`, `plural_categories`, `empty_values`, `orphan_metadata`) | **Not ack-able.** These are correctness failures, not heuristics. The state file does not record acks for them; the writer rejects entries with these rule names. |

Hash format is **always** `sha256-16` (SHA-256 truncated to the first 16 lowercase hex chars), matching `@key.source_hash`. When v1.x adds a new algorithm, the field becomes `sha256-16:67be79359de4aa3f` and old/new can coexist; out of scope for v1.0.

---

## Lifecycle

### Soft mode (default)

1. `dialect check` runs every rule.
2. For each issue produced, it loads `.dialect/state.json` (or treats it as empty if missing).
3. If `checks[<id>].acknowledged` matches the recomputed fingerprint, the issue is suppressed from the report. A summary line at the end notes how many issues were dismissed by acks.
4. Otherwise the issue is reported normally.

### Acknowledging an issue

A v1.0.x `dialect check --ack <rule>:<locale>:<key>` flag (or the dashboard, M10+) writes a new entry to `checks`. The fingerprint is computed from the current source/translation state at write-time.

Until that flag ships, the file can be hand-written. The format is small enough that the cost is "one paragraph", and the spec is stable — hand-written files won't break.

### Stale acks

When the fingerprint at check-time differs from the stored `acknowledged` value, the ack is **stale** — the source or translation has changed since acknowledgement. The warning surfaces again. The stale ack entry is preserved in the file (we don't auto-delete reviewer intent), but `dialect check` shows it in the report so the reviewer can re-ack or remove it:

```
⚠ stale-ack  glossary:ar:checkout.yourTripHeader
  The source value has changed since this acknowledgement was recorded.
  Re-ack with `dialect check --ack glossary:ar:checkout.yourTripHeader`,
  or delete the entry from `.dialect/state.json`.
```

### Missing rule

If `checks[<id>].rule` references a rule Dialect no longer ships (a renamed rule in a major version, a removed third-party rule), `dialect check` emits an info-level note and ignores the entry. It does not error.

---

## Worked example

A reviewer working in `example/` accepts the `vi` "Email" carryover and the `es` "Total" carryover:

```json
{
  "version": 1,
  "checks": {
    "source_equality:es:checkout.total": {
      "acknowledged": "0e1c7d6e3b2a4f81",
      "acknowledged_at": "2026-05-22T11:18:42Z",
      "note": "'Total' is identical in en/es."
    },
    "source_equality:vi:settings.emailLabel": {
      "acknowledged": "5f9aab1c2d3e4f60",
      "acknowledged_at": "2026-05-22T11:19:05Z",
      "note": "'Email' is the canonical Vietnamese form."
    }
  }
}
```

Subsequent `dialect check` runs hide both warnings as long as the source values stay `"Total"` and `"Email"`. If `checkout.total` is later renamed to `Subtotal`, the recomputed fingerprint differs from `0e1c7d6e3b2a4f81`, and the warning reappears.

---

## Out of scope for v1.0

- ~~`dialect check --ack` flag implementation.~~ **Implemented** — `dialect check --ack <rule>:<locale>:<key> [--note <text>]` writes entries; the file can still be hand-edited.
- Acknowledgements for structural rules. Structural issues are correctness, not heuristics — fix the underlying problem.
- Workspace-shared acks (a separate committed file). Teams can choose to un-gitignore `.dialect/state.json`; we don't prescribe.
- Migrating between hash algorithms. When needed, fingerprints become `sha256-16:<hex>` so a future algorithm can coexist. Not blocking v1.0.
- A schema-stamped `$schema` field. The spec at `dialect/spec/state.md` owns compatibility; the version integer is the wire-level signal.
