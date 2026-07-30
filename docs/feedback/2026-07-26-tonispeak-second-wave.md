# Dialect — Toni Speak, second wave (adopting 97f887c, plus a new blind spot)

Run context: same project as the [first wave](2026-07-25-tonispeak-vietnamese-wave.md) — a Flutter
app with a learner surface and an operator console, `en` → `vi`. This round added a cohort-metadata
block to the operator's registration form: **20 new keys**, one new slot, three exemptions narrowed.

Binary: **1.2.0-dev @ 97f887c** — the commit that answered the first wave. This is the report on
using those answers.

---

## The four fixes, used in anger

| # | Fix | Verdict |
|---|---|---|
| D1 | `init` writes `l10n.yaml` + seeds the template ARB | Not re-exercised (this project was already initialised), but the reasoning is right, and "the seed is byte-identical to what `sync` writes" is the detail that makes it safe rather than a phantom first diff. |
| D2 | `toolchain.min_version` + a check that enforces it | **Adopted, and it deleted 22 lines of prose.** |
| D3 | `=== Slot budgets ===` in the header + CHANGELOG | Fixed. I added a sixth slot this round without having to go looking for the feature. |
| D4 | `glossary_exempt` takes a term list | **Adopted on three keys, and it caught a real bug the same minute.** |
| — | `dialect lock <key> [locale]` | Landed after I had already hand-edited three `@key` blocks this round; unused so far, but the hints now print the runnable command, which is the part that makes it discoverable. |
| Q1 | `check --fix --no-stamp` | Answered, and `dialect/spec/source_hash.md` is the right home for the "why not a sidecar" reasoning. |

### D2 — the floor is better than the pin I asked for

I suggested stamping the exact commit. You shipped a **floor**, with pre-release suffixes ignored,
and that is the better call: an exact-commit pin fails for anyone on a released binary, and it fails
for the person building the very tip it was stamped from. I would not have got there from this side,
because from here the failure mode looked like drift rather than over-constraint.

What it replaced in this repo: a 22-line hand-written comment block telling the reader to check
`dialect --version` before running anything. It is now three lines of YAML that `check` enforces, and
the header simply points at them. That block came from stepo, and stepo's had rotted into naming
three different versions — the thing that must not happen again now cannot.

### D4 — the per-term exemption found a real mistranslation immediately

Toni Speak's glossary locks `take` → *bản thu* (a stored recording). Three keys carried
`glossary_exempt: true`, which switched the glossary **off** for everything else in those strings.

Narrowing them surfaced a key I had exempted for the wrong reason:

```
✗ vi.arb:65  glossary  Translation for `authOneDoorNote` does not appear to use the
             glossary term "take" (expected something like "bản thu").
```

The source is *"Once you're in **we take you** to the right place"* — the ordinary verb, not a
recording take. Under `true`, that whole string sat outside the glossary silently. Under
`["take", "console"]` the check names exactly which two words are waived and keeps enforcing the
rest. **`glossary_exempt: true` in a diff tells a reviewer nothing; `["take", "console"]` is
reviewable.** That was the argument for the change, and it held on first contact.

---

## New this round

### N1 · An `x-slot` naming a slot that does not exist is silently ignored — medium

A deliberate probe, because this is the failure I would never notice in normal use:

```jsonc
"@setupRegionCentral": { "x-slot": "option_chippp" }   // typo: no such slot
```

`dialect check` says **nothing**. No warning, no unknown-slot error. The key simply has no budget,
while the ARB still reads as though it has one.

That is worse than declaring no slots at all, because the file now *documents* a constraint nobody is
enforcing. Everything else in the format is validated — an undeclared placeholder is an error, a
missing CLDR category is an error — so `x-slot` is the one piece of metadata where a typo is free.

**Suggestion.** An `x-slot` naming something absent from `slots:` should be a `check` error (a warning
at minimum), listing the declared names. Both sides are already loaded; it is a set-membership test.

*For contrast, when the name is right the check is excellent.* A 21-character Vietnamese value against
`option_chip: { max_length: 10 }` produced exactly the message you would want, including the source
length to compare against.

### N2 · The orphan-guard message misdiagnoses a deliberate deletion — low

I removed two keys from `dialect/source/en.arb` on purpose (two cohort-tile subtitles a redesign made
redundant). `sync` correctly refused:

```
✗ refusing to run — the generated output holds 2 key(s) that are not in your source.
  They were almost certainly added straight to a generated file, bypassing Dialect:
```

The guard is right and both offered remedies are right. The **diagnosis** is wrong for what is
probably the more common case: I did not add anything to a generated file, I deleted something from
the source. A reader who trusts that sentence goes hunting for a mistake they did not make.

**Suggestion.** Name both causes neutrally — "either they were added straight to a generated file, or
they were removed from your source" — and put `--prune` beside the deletion reading instead of
leaving the reader to pair them up.

### N3 · Extraction is blind to default parameter values — medium, and it is a *product* gap

Two strings have now reached a device in English through a completed, `check`-clean localization
round. Both were **default argument values**, not call-site literals:

```dart
class OperatorBadge { const OperatorBadge({this.label = 'OPERATOR'}); }
class MicStrip { const MicStrip.ready({this.label = 'Tap to speak'}); }
```

Neither appears at any call site, so a sweep of call sites — human or agent — finds nothing, and
`check` has nothing to check, because the string never became a key. The first was caught by a device
pass last wave. **The second shipped anyway this wave, in the same shape, on the learner's
most-looked-at control.** Twice is a pattern, not luck: the review was call-site-shaped and the defect
lives one level up from a call site.

This is the only class of miss I have hit in two waves that Dialect cannot see, and the only one where
"run the app and look at it" is the sole defence — which is the kind of work a tool should be doing.

**Suggestion, roughly in order of cost:**

1. `dialect scan` (or `check --unextracted`): sweep the platform's source for string literals that
   are not obviously identifiers and report the ones shaped like display copy. Noisy once,
   suppressible with a marker.
2. Narrower and far less noisy: report **default parameter values and field initialisers** that are
   non-empty string literals in widget/component constructors. Both misses lived exactly there, and
   the pattern is syntactically recognisable without understanding the code.
3. Cheapest: a line near *what NOT to extract* in the convention header saying a default argument
   **is** user-facing copy and must be a key — showing the nullable idiom (`this.label` +
   `label ?? l.someKey`), since that was the fix both times.

Even (3) would have caught the second one, because the header is the file I am told to read first.

---

## Scale and shape, for the record

284 keys, 1 target locale, 6 slots, 36 slotted keys, 3 per-term exemptions, 9 locked identities.
`check --fix && sync && check` clean. `check --strict` and `sync --dry-run` both run in the repo's
pre-push hook, so drift between `dialect/` and `lib/l10n/` cannot reach CI.

Nothing was worked around inside Toni Speak this round, and nothing the CLI owns was hand-edited
except the three `@key` locks — which is what `dialect lock` now exists for, and what the next wave
will use.
