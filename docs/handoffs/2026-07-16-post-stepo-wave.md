# Handoff: enhancements from Dialect's first real project (Stepo, 2026-07-16)

Stepo shipped its Vietnamese localization on Dialect: 751 keys, 17 namespaces,
Flutter + `gen_l10n`, `check --strict` clean, verified on device. The raw
friction log is [`docs/feedback/2026-07-16-stepo-vietnamese-wave.md`](../feedback/2026-07-16-stepo-vietnamese-wave.md);
this handoff turns its open items into implementable work, ordered by value.
Everything here ships with regression tests, on `main`.

## 1. Glossary enforcement for multi-word terms (the big one)

The glossary check tokenizes on whitespace, so any multi-word term is silently
unenforced. In Stepo that is most of what matters: the invariant verb
"step with" → "bước cùng", the chip "On air" → "Lên sóng", and every
multi-word tier title ("Có mặt từ đầu", "Chung vui về đích", "Bạn đồng hành",
"Trọn hành trình"). A glossary that cannot police its most branded entries
fails at its one job.

Design sketch: match source-side terms as case-insensitive substrings over the
source string (word-boundary aware so "step" does not fire inside "steps"
unless the term is "step"); when a source term matches, require the target
locale's term as a substring of the translation. Multi-word target matching
needs no tokenizer at all. Keep `glossary_exempt` as the escape hatch. Add the
warning to `check` (soft) and `--strict` (error), with the usual `file:line`
and remediation hint. Tests: multi-word source hit + correct translation
(clean), multi-word source hit + missing target term (warn), exemption
(clean), the "steps"/"step" boundary case.

## 2. `dialect lock` command

Locking a source-equal untranslatable is currently a two-step hand-edit:
`check --fix` writes the `source_hash`, then a human hand-adds
`"locked": true`. One command should do it:

```
dialect lock <key> [--locale vi]     # writes locked: true + current source_hash
dialect unlock <key> [--locale vi]
```

Refuse to lock when the entry is stale (source changed since translation)
unless `--force` — locking a stale pair silently blesses a mistranslation,
the exact dishonest state the hash exists to prevent. Tests: lock writes both
fields, lock-while-stale refuses, `--force` overrides, unlock removes cleanly.

## 3. Per-locale `glossary_exempt`

`glossary_exempt` is source-wide: exempting a key exempts every locale. Stepo's
case ("Bền bỉ" is a title in its own right, not the literal "supporter") was
fine to exempt globally with one target locale, but the first project with two
locales will want per-locale exemption. Accept both shapes:
`"glossary_exempt": true` (all locales, today's behavior) and
`"glossary_exempt": ["vi"]`. Tests for both, plus the spec/docs note.

## 4. `init --locales` (small)

The README's own usage story is "run dialect init… Target Spanish, Japanese,
and Arabic," but `init` takes no locale targeting; the AI edits `dialect.yaml`
afterward. `dialect init --locales vi,ja` should scaffold `dialect.yaml` with
those targets so the scaffold matches the story. Keep the flag optional.

## Done in the Stepo wave (do not redo)

Version-skew pinning guidance, `flutter: generate: true` in the init plan, the
strict-clean example with file-locks, README/executable reconciliation,
AGENTS.md/CLAUDE.md-respecting init, ARB placeholder declaration order,
`tag_balance` counting per rendered ICU message (with the Vietnamese
`other`-only collapse case), `lock_integrity`, and the rich-text `<b>` recipe
doc. All on `main` through `8dcf30d`.
