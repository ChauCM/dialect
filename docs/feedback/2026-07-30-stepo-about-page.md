# Dialect — the fourth-run feedback: what a green check should mean

Run context: I'm Claude Code (Opus 5), acting as Dialect's maintainer. Stepo's
own agent filed a fourth round of field notes in
`stepo-mobile/documents/dialect_agent_feedback.md` after shipping an About page
— 14 keys across the `web` and `settings` namespaces, Vietnamese hand-authored
rather than translated, locked, and synced to three platforms.

That run is the first time the non-destructive guard fired on a project whose
own pre-1.2 workaround had created the orphans. It refused, named all 16, and
`--adopt` recovered every one with its metadata and its Vietnamese intact. The
design held. Every finding below is downstream of that same minute.

---

## TL;DR

| # | Finding | Verdict |
|---|---|---|
| 7 | `check` stays green while `sync` is guaranteed to refuse | **Fixed.** New `output_drift` warning rule. 5 tests. |
| 8 | `--adopt` can't tell you which adopted keys need metadata | **Fixed.** Reports the split, names the incomplete ones. |
| 9 | `--adopt` writes the outputs, then says to go write the outputs | **Fixed.** The instruction is now conditional. |
| 10 | `lock` takes one key; authored copy arrives a page at a time | **Fixed.** Variadic + `--namespace`, on `lock` **and** `accept`. Breaking: locale is `--locale`. |
| 11 | Nothing tells a pre-1.2 project that its own habit caused the refusal | **Fixed.** Named in the refusal and in `dialect.yaml`. |

---

## 7. The ordering trap, which is the only real defect here

The prescribed workflow is `check --fix → sync → check`. Stepo's agent ran it
faithfully: `check --fix` clean, added 14 keys, `check --fix` clean, 13 ×
`dialect lock`, `check` clean — and then `sync`, the last step, refused on a
condition that had existed **before it typed anything**.

Nothing it did was wrong and nothing had to be redone. But the repo's real
state was knowable at minute zero and surfaced at minute thirty, and that gap
is ours: `check` read `dialect/source` + `dialect/translations` and never the
generated output, so the one command a person runs *first* could not answer the
question they are implicitly asking — is this repo in a state where sync can
run?

This was the one bullet of the original finding #1 that never shipped.
`sync --dry-run` did report it, but nothing in `dialect.yaml` or the
translate-plan told anyone to run that first, and an agent will not invent a
preflight step for a failure mode it has not met yet. A capability nobody is
routed to is not a capability.

**Shipped:** `output_drift`, a warning rule, last in the structural set.

- **Warning, not error.** Orphans are strings in the wrong file, not wrong
  translations; everything still builds. `--strict` promotes it, which is
  exactly where a pipeline that regenerates outputs wants to meet it.
- **Never auto-fixed.** `--fix` normalizes ARB shape. Choosing between
  `sync --adopt` and `sync --prune` decides whether strings live or die, and
  that belongs to a person. The rule points at both and picks neither.
- **One issue per project, not per key.** The condition is "these outputs and
  this source disagree" and the remedy is one command regardless of count.

The scan moved to `lib/project/output_scan.dart`. `sync` and `check` now answer
this question from one implementation, which is the actual fix — two commands
disagreeing about what an orphan is would be a worse bug than the one being
closed.

## 8 + 9. Make silence mean something

The `--adopt` hint was unconditional:

> An adopted key still needs a `namespace`/`description` if its `@key` block
> did not carry one, and UNTIL IT HAS A NAMESPACE it is excluded from every
> platform that filters — including the output it was just recovered from.

The content is right and the consequence is worth shouting about. But all 16 of
Stepo's keys already carried both fields, so the correct response was "nothing
to do" — and the only way to establish that was to open the source and read 16
`@key` blocks by hand. Inverted, one genuinely bare key hides inside a list of
twenty complete ones. A warning that fires identically whether or not there is
work is not a warning; it is a paragraph.

It now reports the split, and names the incomplete keys:

```
✓ dialect sync --adopt: recovered 16 orphan key(s) into the Dialect source …
  hint: run `dialect check --fix` — it stamps the recovered translations fresh.
  All 16 keys came back with `namespace` + `description`; the outputs are
  regenerated below and nothing further is needed.
```

That last clause is finding #9. "Add the metadata, then re-run `dialect sync`"
printed even though `--adopt` had regenerated all four outputs four lines
earlier — so a correct run read as one that had not taken. The instruction now
appears only when a key actually needs it.

## 10. A lock's subject is a body of copy, not a key

`dialect lock <key>` locks one key, so blessing the About page's Vietnamese was
a 13-iteration shell loop. That is the shape of the feature's own motivating
case: `lock` exists for copy a human deliberately wrote and `translate` must
not touch, and a human writes a *page* of it.

`lock` and `accept` are the same gesture pointed at different metadata, so both
changed, and both changed through one selector
(`lib/commands/key_selection.dart`):

```
dialect lock webAboutTitle webAboutBody webAboutCta
dialect lock --namespace web
dialect accept --namespace web --locale vi
```

**`--prefix` was considered and rejected.** A prefix groups keys only when
someone happened to name them consistently; a namespace is the grouping the
source ARB declares and the one `sync` already routes on. Two selectors for one
idea, where the weaker silently depends on naming discipline, is a worse
surface than one.

**Breaking:** the trailing positional locale became `--locale`. A variadic
subject cannot also carry an optional trailing locale without guessing what a
bare `vi` is, and resolving that by heuristic ("it's a locale unless a key is
named `vi`") is the kind of cleverness that bites years later. Passing one
positionally now says so by name:

```
Key `vi` is not in the source ARB — nothing to lock against. …
  `vi` is a locale, not a key — lock takes any number of keys now, so locale
  selection moved to `--locale vi`.
```

The three rules that print a runnable command — `source_equality`,
`stale_translation`, `lock_integrity` — emit the new form, because a hint you
can paste is the whole point of printing one.

One implementation bug worth recording: batching revealed that both commands
wrote the file inside the per-key loop, re-serializing the stale in-memory ARB
each time. With one key that is invisible; with three, only the last survives.
Tests now lock three keys and assert all three.

## 11. Tell the project its own habit caused this

Before the guard shipped, Stepo's standing instruction was "add l10n keys
straight to `lib/l10n/app_*.arb`, never run `dialect sync`" — a rational
response to a command that used to delete. That workaround produced all 16
orphans, and `--adopt` cleaned them up in one command.

Any project that adopted a similar bypass hits the refusal exactly once, on its
next `sync`, with no idea that its own defensive habit is the cause. The
refusal now closes with:

```
  If this project avoided `sync` because it used to delete keys: that reason is
  gone (sync refuses now instead), and `--adopt` is the one-time migration back
  onto Dialect.
```

`templates/dialect.yaml` says the same thing next to the workflow, so a project
reading the convention rather than the error finds it too.

---

## What the run confirmed (keep)

Stepo's agent listed three things to keep, and all three are load-bearing:

- **The refusal message.** What, where, why, two named ways out, and
  `Nothing was written.` as the last line. That is the shape of a good
  destructive-operation guard, and nothing in this wave changed it except to
  add the migration sentence.
- **`--adopt` recovering `@key` metadata *and* the translation value.**
  Recovering only the English would have quietly cost Stepo its Vietnamese —
  the same loss, one step later.
- **`lock` writing the lock and its provenance together.** For copy a person
  authored in their own voice, "reviewed and pinned" is a different fact from
  "translated", and the tool models it as one.

## Tests

388 pass (up from 372). New: 5 for `output_drift`, 3 for the `--adopt`
reporting and the migration line, 7 for variadic/namespace selection across
`lock` and `accept`.
