# Dialect — the fifth-run feedback: from consistent files to correct copy

Run context: I'm Claude Code (Opus 5), acting as Dialect's maintainer. Stepo's
agent sessions filed a fifth round of field notes after two days in which four
different agents pushed roughly 80 key additions and 30 retirements through
source + translations — a feedback screen, a recognition card with a generative
sentence system, sheets, a share-link fix — en + vi, glossary-checked, with zero
l10n regressions reaching a device.

The headline is not a request. It is that **the 2026-07-17 data-loss fix is
verified in anger**: an agent deleted four keys through the source path while
the generated output still carried them, `check` flagged `output_drift` naming
all four, `sync` refused until an explicit `--prune`, and the prune printed
exactly what it dropped. The failure mode that destroyed seven keys in July is
now a guided decision. That was the highest-severity item on the list and it
closes with confidence.

What that leaves is a different question. Dialect could answer "are these files
consistent with each other?" It could not answer "is this copy right?" Both
suggestions in this round are that question, and both are worth building.

---

## TL;DR

| # | Suggestion | Verdict |
|---|---|---|
| 12 | Plural-shape lint — two shipped strings said "1 people" | **Built.** New `plural_shape` rule. 28 tests. Found 4 real defects in Stepo's live corpus, 0 false positives. |
| 13 | Project-configurable copy lints beside the glossary | **Built.** New `banned:` block + `banned_pattern` rule, with `except:` and a dead-entry audit. 24 tests. |
| 14 | Fold the trailing `check` into `sync` | **Built.** `sync` always reports its post-state; `--verify` makes it the exit code. |

Shipping as **1.3.0**. No breaking changes: no output contract moves, no
argument grammar changes, and both new rules are warnings, so an existing CI
job that does not pass `--strict` sees the same exit codes it saw before.

---

## 12. Plural shape — the suggestion was right, the proposed test was not

The report: two shipped English strings rendered "1 people", because a count
placeholder was interpolated without ICU plural syntax. The proposed check was
"flag any number placeholder adjacent to a countable noun that isn't wrapped in
a plural block."

The diagnosis is exactly right, and it names a real hole. `plural_categories`
checks that a plural is *complete* once one exists — that is the rule that
caught an Arabic itemCount defect during validation. Nothing checked that a
plural should have existed at all. The one command that reads every string
could not see the most basic thing wrong with one.

**"Countable noun" is the part I could not build.** Dialect has no lexicon and
should not grow one. So the first cut used the signals actually available —
declared placeholder type, conventional placeholder names, and a stop list of
words a number can precede harmlessly — and I ran it against Stepo's live
`en.arb`, ~900 keys.

Nine warnings. Four real:

```
composerFinalStepFloor   'A journey needs {floor} steps before it can finish…'
landingCardSteppedWith   '…{name} and {others} others stepped with this'
stepCardPromptRegular    '…in the next <b>{hours} hours</b>…'
stepPeopleDaysLater      '{days} days later'
```

Five noise: `{count} stepped with you`, `{liveCount} live now`, `Resend code in
{seconds} s`, `{count} since you last looked`, and one more of the same shape.

**The noise is what taught me the rule.** Every false positive was a count in
front of a verb, an adjective, a unit abbreviation, or a preposition — all
singular in form. Every true positive was a count in front of a word that is
*already plural*. Which is obvious in hindsight and is the definition of the
defect: the author wrote the many-case and left the one-case to break. So the
rule fires only when the following word is plural — regular `-s`, minus the
`-ss` / `-us` / `-is` singulars that would sneak through, plus the irregulars
English actually uses in UI copy, starting with "people".

Re-run on the same corpus: **four warnings, all four genuine, zero noise.**

The cost is the mirror defect — a source written singular, `{count} step`,
which breaks at 2 rather than at 1. Catching that would mean treating every
singular noun after a count as suspect, which is most of a corpus. Named in the
rule's doc comment rather than pretended away.

**One thing worth reporting back to Stepo.** `landingCardSteppedWith` is a live
bug, and it is hiding inside a plural that already exists:

```
{count, plural, =1{<b>{name}</b> stepped with this}
                other{<b>{name}</b> and {others} others stepped with this}}
```

At `count = 2`, `others` is 1, so the `other` branch renders "and **1 others**
stepped with this." An existing plural on one variable says nothing about a
second one. This is also the case that justified keeping the declared-type
signal: `others` is not a conventional count name, and the only reason the rule
saw it is that the ARB declares `"others": {"type": "int"}`. Metadata that
looked like bookkeeping turned out to be the thing that caught the bug.

## 13. Banned patterns — and the correction the probe forced

The request: a `banned_patterns` section in the project config, because Stepo
bans em-dashes in user-facing copy and enforces it with a hand-rolled Flutter
test carrying a quarantine list, which the web consumer has no equivalent of at
all.

Two ownership calls the request did not ask for.

**It goes in `glossary.yaml`, not `dialect.yaml`.** A glossary says *always say
this*; a ban says *never say that*. Same question, same reviewer, same diff.
Splitting the pair across two files so that one lands next to `target_locales`
and `publish.production.bucket` would be filing by mechanism instead of by
meaning. `dialect.yaml` stays plumbing.

**It checks the source too.** The em-dash rule is a rule about English, and
English is the source locale. A version scoped to translations would have left
the language the rule was written for unchecked. `locales:` narrows it back
down when a rule really is about one language.

**Then I probed it against the real corpus, and I was wrong about the premise.**
I expected to find copy their guard was missing. Their guard is better than the
report implies: it already reads the ARB rather than the Dart files it
originally scanned, it already quarantines by key name, and it already has a
second test asserting the quarantine has no dead entries. `banned_pattern`
found exactly the six keys their list names — no drift, nothing leaked.

That is a real correction to make out loud, because it changes what the feature
is for. Dialect is not fixing a broken guard here. It is making one guard serve
every consumer of the source instead of the one stack it happened to be written
in — which is precisely the gap the report named for the web consumer.

**But the probe did expose a design gap in my first cut.** I had built exactly
one escape hatch: the existing ack mechanism, fingerprinted so it expires when
the value is edited. I argued that this dissolves the stale-quarantine problem.

It does not, for Stepo's actual case. Their six exemptions are not "this one
use is right." Four of them are a **standing ruling**: the PO ruled the push
journey bodies exempt because those bodies mirror an established notification
grammar. Fix a typo in one and an ack would expire — but the ruling still
holds. A fingerprint is the wrong instrument for a policy decision.

So `banned:` entries take `except:`, a list of keys ruled exempt for good. Two
kinds of exception, because copy policy has two:

| | expires when the copy changes | survives an edit |
|---|---|---|
| **`--ack`** | yes — that is the point | |
| **`except:`** | | yes — a ruling is not a fingerprint |

And because a standing list is exactly the artefact that rots, the rule audits
its own: a name in `except:` whose copy no longer contains the pattern is
reported, so the list can only shrink. That is their second test, the one that
keeps the quarantine honest — now shipped rather than hand-written.

Verified end to end: I reconstructed their real quarantine list as `except:`,
including `composerMilestoneAbout`, which their comment records as swept in
Phase 2. Six live exemptions produced zero noise, and the swept one was named:

```
⚠ banned_pattern  1 key(s) named in the `except:` list for `—` no longer
                  contain it: composerMilestoneAbout.
  hint: The copy was rewritten or the key was deleted, so the exemption is
        excusing nothing. Remove those names from `except:` …
```

Eight lines of YAML now do what a 115-line test file did, for Flutter and the
web and the backend at once.

## 14. Sync says where you stand

Every agent ran `check → sync --prune → check` as three commands. The third one
asks a question sync already knows the answer to.

`sync` now ends with one line — `check: no issues.` or a count — and `--verify`
turns that count into the exit code so CI is one command instead of two.

Two deliberate choices. The report is **unconditional**, because a run that
ends "and it is clean" is worth more than a run that ends silently, and it is
free. The exit code is **not**, unless you ask: the files are already written by
then, and a report on the project's state is not a verdict on whether the write
succeeded. `--dry-run` wrote nothing, so it reports nothing.

Acks apply here exactly as in `check`, so an acknowledged warning does not
reappear at the end of every sync.

---

## What this round changed about the package

1.2 was about not losing work. 1.3 is the first release where `dialect check`
has an opinion about the *writing*, not just the bookkeeping — and both rules
came from a defect that had already shipped to real users.

The pattern worth keeping: **both rules were built, then run against a real
corpus, then rewritten.** `plural_shape` went from 44% precision to 100% because
the false positives had a shape. `banned_pattern` grew `except:` because the
probe showed my one escape hatch was the wrong instrument for half the real
cases. Neither correction was visible from the feedback text or from the unit
tests — only from pointing the thing at ~900 keys someone actually shipped.

Open, not built: a `--fix` for `plural_shape` that rewrites the string into a
plural block. It needs the singular form of a noun, which is a lexicon, which is
the line this package does not cross. The hint gives the exact ICU skeleton to
paste instead.
