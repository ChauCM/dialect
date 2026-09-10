# `.dialect/state.json` — Soft-Mode Acknowledgement Store

**Status:** v1.0. Stable contract. Breaking changes require a major-version bump.

**Owners:** `dialect check` (reads on every run; writes via `dialect check --ack <rule>:<locale>:<key>` — **implemented**), the dashboard (M10+ — reads to render "dismissed" badges).

---

## What it is

`dialect check` runs in two modes: soft (default) and `--strict` (CI). In soft mode, warnings are surfaced but don't fail the exit code; in strict mode they do (with the `length_ratio` carve-out — see M8). A reviewer working through soft-mode output needs a way to say "this warning is intentional, stop showing it" without globally flipping to strict or editing the rule code.

`.dialect/state.json` is that store. It records per-issue acknowledgements keyed by `<rule_name>:<locale>:<translation_key>`, fingerprinted with the source value that was acknowledged. When the source value changes later, the fingerprint mismatches and the warning surfaces again — acknowledgement is **tied to the source state at ack-time**, the same way `@key.source_hash` ties a lock to its source.

**The ledger is committed.** `dialect init` ignores `.dialect/*-plan.md` and leaves `.dialect/state.json` tracked.

An acknowledgement is a linguistic ruling about a string, fingerprinted to that string. Nothing in the record is machine-local — no paths, no environment, no absolute times that mean anything only on one box. And `--strict` reads it: a gate whose verdict depends on an untracked file is not a gate. A repo that ignores the ledger and runs `dialect check --strict` in CI or a pre-push hook cannot pass its own check from a fresh clone, because the adjudications live only in the tree that made them, and the person who gets refused cannot see what was decided or by whom.

Earlier versions ignored all of `.dialect/`, under a comment describing the directory as ephemeral plan files. That was true of the plan files and false of `state.json`, which nothing regenerates. `dialect init` replaces that line where it finds it.

---

## File layout

Single file at the project root:

```
.dialect/state.json
```

`dialect/` (canonical convention dir) and `.dialect/` (working directory) are different paths. Inside `.dialect/`, the `*-plan.md` files are ephemeral — every command rewrites its own — while `state.json` is durable and committed.

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

## Ack lifecycle

An entry is in exactly one of four states, and `dialect check --list-acks` is the only thing that reports all four:

| State | Fingerprint | Warning this run | Meaning |
|---|---|---|---|
| `live` | matches | suppressed one | Load-bearing. |
| `inert` | matches | none fired | Still a true ruling about the current text; the warning's cause moved or the rule narrowed. Kept. |
| `lapsed` | drifted | either | The text was edited after the ruling. Nobody adjudicated what is there now. |
| `orphaned` | unresolvable | none | The key is gone from the ARB. |

Only the `lapsed`-and-still-firing case reaches a normal run, as `⚠ stale-ack`. The rest are invisible to it by construction: suppression walks the issue list, so an ack with no issue is unreachable from there. That is the common case in a ledger more than a few months old — copy gets rewritten, the fingerprint stops matching, the rule stops firing, and the entry sits there reading exactly like a live ruling. A maintainer carrying "the tree's acks" forward would publish rulings nobody made and nobody can re-derive.

`dialect check --prune-acks` deletes the `lapsed`, `orphaned` and unparseable entries. It keeps `inert` ones: their fingerprint still matches, so they are judgements someone actually made about text that is still there.

**Do not prune `inert` entries in a tidy-up sweep.** It is the one rung whose value is invisible in the moment — nothing fires, so nothing shows the ack doing work, and the pressure to delete it is exactly proportional to how well it is working. A passing test looks deletable for the same reason. Prune one only when you can say *why* it went quiet, because two very different causes look identical in the output:

- **The rule stopped flagging that construct.** The waiver is genuinely spent and deleting it is safe. When Dialect narrowed `plural_shape` in 1.5.0, every ack that existed only to silence that misfire became `inert` on the next run.
- **The warning's cause moved and can come back.** A translation was rewritten, a glossary term was retired, a locale was dropped. Restore any of those and the warning returns — with no ruling attached, because the sweep deleted it.

`--list-acks` cannot tell those apart; only a person who knows what changed can. The `note` recorded at `--ack` time is what makes that answerable months later, which is the strongest argument for writing one.

Because the ledger is committed, each entry appears in a diff. The case worth a reviewer's attention is an entry that **survives** an edit to the string it rules on — that is a waiver being carried onto text nobody re-read — which is why `--list-acks` exists rather than a bare count.

---

## Out of scope for v1.0

- ~~`dialect check --ack` flag implementation.~~ **Implemented** — `dialect check --ack <rule>:<locale>:<key> [--note <text>]` writes entries; the file can still be hand-edited.
- Acknowledgements for structural rules. Structural issues are correctness, not heuristics — fix the underlying problem.
- Per-author ack scoping. The ledger is one shared file; `acknowledged_by` records who ruled, but there is no mechanism for one author's acks to apply only to their runs.
- Migrating between hash algorithms. When needed, fingerprints become `sha256-16:<hex>` so a future algorithm can coexist. Not blocking v1.0.
- A schema-stamped `$schema` field. The spec at `dialect/spec/state.md` owns compatibility; the version integer is the wire-level signal.
