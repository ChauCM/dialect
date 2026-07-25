# Dialect — Toni Speak, first wave (en → vi, whole app)

Run context: I'm Claude Code (Opus 5), localizing [Toni Speak](https://github.com/ChauCM) — a Flutter
app with two surfaces behind one login (a learner speaking screen and an operator console used by a
Vietnamese teacher to run a research recording study) — from `en` to `vi` in a single round. Binary:
**1.2.0-dev @ f18ac72**, matching the pin block in the project's `dialect.yaml`.

Scale: `dialect init` on an app with **zero** prior localization, ~14.5k lines of Dart, ending at
**266 keys**, 1 target locale, `check --fix && sync && check` clean, 215 tests green.

Dialect is ours, so friction here is product signal rather than something to route around.

---

## TL;DR

**The tool did the job and stayed out of the way.** The end-to-end path — `init` → write source →
`check --fix` → write translations → `check --fix` → `sync` → `gen-l10n` — worked first time with no
workarounds and nothing hand-edited that the CLI should have generated. The four defects below are
all in the **first ten minutes**, before a single key exists.

| # | What | Severity |
|---|---|---|
| D1 | `init` does half the gen-l10n wiring, and the missing half is a hard `flutter pub get` failure | **high** — it is the very next command anyone runs |
| D2 | The scaffolded `dialect.yaml` has no pin block, so every project hand-writes one and stepo's rotted | **high** — the failure is silent and the pin is what stops it |
| D3 | The convention header never mentions `slots:`, though the scaffold writes an empty one | medium |
| D4 | `glossary_exempt` is all-or-nothing per key | medium |

Plus two things that went **better** than expected (W1, W2), and one design question (Q1).

---

## D1. `init` writes `generate: true` but not `l10n.yaml` — and the gap is a build failure

`dialect init` did a lot right: it scaffolded `dialect/`, created `AGENTS.md` (correctly — it did
**not** clobber the repo's existing root `AGENTS.md`), added `.dialect/` to `.gitignore`, and added
`flutter: generate: true` to `pubspec.yaml`. Every one of those is the right call.

Then the init plan's §1.2 asks the *agent* to hand-create `l10n.yaml` with three lines that are the
same three lines in every Flutter project. So `init` owns one half of the gen-l10n wiring and
delegates the other half — and it's the half that fails loudly:

```
$ flutter pub get
Got dependencies!
Generating synthetic localizations package failed with 1 error:
Error: The 'arb-dir' directory, 'LocalDirectory: '.../mobile/lib/l10n'', does not exist.
```

That is the **first command a developer runs after `init`**, and it errors. Worse, it errors even
after you write `l10n.yaml` correctly — because `lib/l10n/` does not exist until the first
`dialect sync`, which cannot happen until keys exist. So the honest sequence is "init, then a
scary-looking failure for as long as it takes you to write your first key", and the error text names
`arb-dir` rather than saying "run `dialect sync` first".

**Suggestion.** `init` should either (a) write `l10n.yaml` and seed `lib/l10n/app_en.arb` from the
same example key it already puts in `dialect/source/en.arb` — after which `flutter pub get` is green
from minute one — or (b) if there is a reason not to, say so in the plan. Right now the plan reads as
if `init` simply forgot.

## D2. No pin block in the scaffold — so every project hand-writes one, and they rot

The stepo `dialect.yaml` carries a hand-written pin block that says three incompatible things:

```yaml
#   Dialect version: 1.1.0
#   Pinned commit:   e20ca71  (github.com/ChauCM/dialect, main)
#     cd ~/Documents/github/dialect && git checkout 7dffb6d      # ← a third value
```

A version, a "pinned commit", and a *different* commit in the rebuild instruction. That block reads
as authority while pointing at nothing, and it got copied into a second project's instructions as
the pattern to follow. I wrote Toni Speak's by hand too, and the only thing that stopped the same
drift was noticing stepo's first.

This is worth fixing in the tool because **the pin is precisely the thing nobody re-derives.** The
CLI already knows both facts about itself.

**Suggestion, in order of value:**

1. `dialect init` stamps the version **and** the commit it ran as, into the scaffolded `dialect.yaml`
   (`toolchain: { version: 1.2.0-dev, commit: f18ac72 }` as real YAML, not a comment).
2. `dialect check` warns when the running binary disagrees with the stamped pin. That converts a
   comment nobody reads into a check that fires on the one day it matters — the day someone runs a
   stale binary and gets destructive `sync` behaviour that 1.2.0-dev fixed.
3. `dialect --version` printing the commit alongside the version would make step 2's message
   actionable without a `git log`.

## D3. The convention header never mentions `slots:` — the newest feature is invisible where it counts

`dialect init` scaffolds `slots: {}` with a good comment block **below** `length_ratio`, near the
bottom. But the file's own header — the ~200 lines that open with *"If you are an AI assistant: read
this entire file before extracting or translating any strings. It is the spec."* — documents key
naming, `@key` metadata, placeholders, plurals, currency, glossary, what not to extract, and the
workflow. It does not mention width budgets at all.

The practical consequence, in this run: I wrote the size constraint into **fifteen `description`
fields as prose** ("Rendered uppercase in a 9pt pill, so it must stay very short", "Sits in a 68px
column…") before noticing `slots:` existed at all, and I only noticed because I read the changelog
for an unrelated reason. Prose in a description is a hope; a slot budget is a check.

Related: the `Size-aware translation: width budgets for tight UI slots` commit (f18ac72, the pinned
tip) has **no CHANGELOG entry**. The changelog's `[Unreleased]` section documents `accept`, the
empty-hash fix, the placeholder-only glossary fix and the non-destructive `sync` — but not the
feature at the tip.

**Suggestion.** A `=== Slot budgets ===` section in the header template, next to `=== Placeholders
===`, ~10 lines: what `x-slot` and `x-max-length` do, that they are opt-in, and that the real payoff
is `dialect translate` handing the budget to the agent up front. And a changelog entry.

## D4. `glossary_exempt` is all-or-nothing per key

Toni Speak's glossary locks `take` → *bản thu* and `sentence` → *câu*. One key trips both, for two
*different* and both-correct reasons:

> **`setupNoCoachingBody`** — founder-written Vietnamese, kept verbatim. It says *lượt thu* (a turn at
> recording) where English says "take", because there the word means the ACT, not the stored
> artifact; and *đọc mẫu* (model the pronunciation) where English says "read the sentence".

Both readings are right, and the wording is not mine to change. But the only escape hatch is
`"glossary_exempt": true`, which switches the glossary off for that key **entirely** — including
`student`, `Toni` and every term it should still enforce. I took it, and I lost real coverage on the
single most important string in the operator flow.

**Suggestion.** Let the field take a list: `"glossary_exempt": ["take", "sentence"]`, with `true`
staying valid as "all". The check already knows which term it is complaining about, so the diff is
small and the exemption becomes reviewable — right now `glossary_exempt: true` in a diff tells a
reviewer nothing about what was waived.

---

## W1. The width-budget check earned its keep in one run

Once I found it (D3), I declared four slots and tagged 29 keys. First run, two warnings, **both
real** — and one of them was a mistake in my own slot definitions rather than in a translation:

```
⚠ Source `ratingAssignedBadge` is 15 chars — over its slot `pill` budget of 12.
  The slot is too tight even for the source string.
⚠ Translation for `scoreUncalibrated` is 15 chars — over the slot `pill` budget of 12 (source is 12).
```

The first one is the check doing something I did not expect and now think is the best thing about
it: **it flags an impossible source**, not just a long translation. My `pill` slot had lumped a
fixed-width 9pt legend swatch together with two chips that size themselves. The fix was to split the
policy into `pill` (12) and `badge` (16) — which is a better description of the UI than what I wrote
by hand, arrived at by being contradicted.

The second is a genuine overflow: "UNCALIBRATED" (12) → "CHƯA HIỆU CHUẨN" (15) in a tiny chip.

Both hint texts were exactly right about what to do, including offering "raise the budget" as a
legitimate answer rather than assuming the translation was at fault.

## W2. `check --fix` → `sync` → `gen-l10n` did not need a single manual touch

266 keys, ICU plurals, a `{status}` int placeholder, six deliberately-identical values, three
glossary exemptions, and `\n` inside values — all normalized, sorted, hash-stamped and generated with
no hand-editing of anything the CLI owns. The `source_equality` hint told me exactly how to lock a
deliberate identity (`"locked": true` **plus** the current `source_hash`, and it was explicit that a
bare lock fails `lock_integrity`), which is the kind of hint that saves a round-trip.

The non-destructive `sync` guard never fired, which is the correct outcome — but I noticed I was
relying on it existing when I chose to let `lib/l10n/` be fully generated and gitignore nothing.

---

## Q1. Should `check --fix` stamp hashes on a file it is seeing for the first time?

Not a defect — a question about the first-run experience.

I hand-wrote `dialect/translations/vi.arb` as 266 flat `"key": "value"` lines: ~280 lines, entirely
reviewable. `check --fix` then rewrote it to **1,339 lines**, because every key gained a three-line
`@key` block holding one `source_hash`. That is correct and it is what makes staleness detection
work. But it means the first `--fix` on a new locale produces a diff a human cannot meaningfully
review, on the one file where the *content* most deserves review.

Two shapes that would keep the review small, if either is compatible with the format:

- a sidecar (`dialect/translations/.vi.hashes.json`) so the ARB stays the human artifact; or
- `check --fix --no-stamp` for the authoring pass, with stamping on the next run.

I am not asking for a change — the current behaviour is defensible and the alternative splits one
file into two. But "the first review of a new locale is 1,339 lines" is worth a deliberate answer,
because it is the moment a translator's work is most worth reading.

---

## What I reached for and did not find

- **`dialect lock <key> [locale]`.** `dialect accept` exists for re-blessing a stale translation;
  there is no sibling for "this value is deliberately identical to the source". I locked six keys by
  hand-editing `@key` blocks in the generated-ish translation file, in a second pass after `--fix`
  had stamped the hashes. `accept` sets the precedent that this class of gesture is a command.
- **A "describe the callsite" pass I could run *before* writing descriptions.** `dialect describe`
  backfills descriptions for keys that already exist; on a from-zero project the descriptions are
  the expensive part of extraction and are written at the same moment as the keys. Not obviously
  fixable, and possibly not worth fixing — noting it because it is where the human hours went.
