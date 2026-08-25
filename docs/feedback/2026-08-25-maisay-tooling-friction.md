# Dialect — MaiSay, the tooling-friction sweep

Run context: **MaiSay**, a Flutter Mandarin-speaking app, `en` → `vi`, ~900 keys, one `arb`
platform with no namespace filter. Same repo as the [Toni Speak
waves](2026-07-25-tonispeak-vietnamese-wave.md) under its post-rename name.

Binary: **1.3.0**, installed via Homebrew. `dialect.yaml` pins
`toolchain.min_version: 1.2.0`.

Source: the project keeps a live friction list rather than a dated report —
`docs/2026-08-23-tooling-friction-from-the-instruction-sweep.md`, addendum of 2026-08-24, written
after building a word-detail sheet. Three of its entries are ours. This is what I did with them.

---

## The three findings

| # | Finding | Verdict |
|---|---|---|
| B | `sync --prune` reports a prune it does not perform | **Real bug, fixed.** `--prune` now deletes the orphan from `dialect/translations/` as well. |
| C | `check --fix` alphabetises, so scripted range edits are unsafe | **Not a bug — documented.** One line, in three places. |
| 3 | Nothing tells you how to run `dialect` | **Papercut, fixed.** One line in the README's Install section and in the AGENTS.md section we stamp into projects. |
| I | The consuming project's pre-push hook skips the check when the binary is absent | **Nothing to build here** — see below. |

---

## B · `--prune` said it had dropped a key and had not

### What was reported

A key (`wordSheetTitle`) was removed from `dialect/source/en.arb`. Then:

```
$ dialect sync --prune
⚠ dialect sync --prune: dropped 1 orphan key(s) absent from the source:
  wordSheetTitle
✓ dialect sync: wrote 1 file(s).

$ dialect check
⚠ output_drift  1 key(s) exist in a generated output but not in the source … wordSheetTitle
```

Re-running printed the same "dropped" line and then `nothing to do`. The loop broke only when the
orphan was deleted from `dialect/translations/vi.arb` by hand.

### Why it happened

`OutputScan` reads the **generated outputs**, which is the right place to look for the failure it
was built for — a key added straight to `lib/l10n/app_en.arb`. But an orphan in the output has two
possible backings, and the code only ever knew about one:

- **output-only** — the key exists nowhere else. Regenerating drops it. `--prune` was correct here,
  and this is the population every test covered.
- **translation-backed** — the key is still an entry in `dialect/translations/<locale>.arb`. It is
  in the output *because sync put it there*, and generation puts it back every single time.

For the second population, `--prune` was a no-op that printed a success line. Structurally, the
report was emitted **after** the write loop, which is why it could describe something the run had
not done.

There was also no check anywhere that sees a key in `dialect/translations/` and not in the source.
`missing_keys` looks the other way (source key with no translation), and `output_drift` reports the
symptom in the generated file while the cause sits in the canonical store. So the whole condition
was only ever visible through its shadow.

### The choice, and why

Two candidates were on the table: **(a)** make `--prune` delete from `dialect/translations/` too, or
**(b)** keep the scope and make the message name the file it did not touch.

I took **(a)**, with (b)'s honesty folded in rather than traded away. Three reasons:

1. **`--adopt` already writes to both canonical stores.** `_adoptOrphans` restores the source entry
   *and* the translated values. The refusal presents the pair as "pick one" — and only one of them
   could actually resolve the condition. Restoring the symmetry is what makes the sentence true.
2. **Under (b) the command's only effect is to print.** A flag whose remedy is "now go hand-edit a
   Dialect-managed file" pushes the operator back into the habit the tool exists to break, and the
   file it sends them to is the one that carries `source_hash` and `locked`.
3. **The "data-loss decision belongs to a person" stance is not weakened by this** — it is what
   selects it. `output_drift.dart` says the fix is never automatic; the person makes the decision by
   typing `--prune`, and `translate_plan.md` already tells an agent not to reach for it. Widening
   what `--prune` deletes makes that warning *more* accurate, not less.

What (a) owes in return is that the person can see the deletion before it happens. That is
`--prune --dry-run`, which now prints the file, the key and the exact string and writes nothing —
an affordance an agent or a CI job can actually use, where a confirmation prompt is not.

### What changed

- **`lib/commands/sync.dart`** — pruning moved ahead of generation; translation-backed orphans are
  deleted from `dialect/translations/<locale>.arb` through `ArbWriter` (surviving `@key` blocks and
  `@@` file metadata preserved); the project is re-loaded so generation reads the pruned files.
- **The report splits the two populations.** Output-only keys are listed as *dropped by
  regenerating* with the files they were in; translation-backed keys are listed as *deleted*, per
  locale, each with its value quoted, plus `git diff -- dialect/translations` as the undo.
- **`--prune --dry-run` prints that list and writes nothing**, and exits 1 when a deletion is
  pending. It used to say `every output is up to date` — technically true and completely
  misleading, since with the orphan still in the translation the generated bytes really did match.
- **The refusal names the translation file too**, per key: `also in dialect/translations/vi.arb —
  regenerating puts it back`. This is the (b) half kept: someone who decides *not* to prune still
  learns where the second copy lives, without running the destructive command to find out.
- **`--prune`'s help text says what it deletes now**, including the translations.

### How it was verified

Three tests in `test/commands/sync_test.dart`, all asserting on **file contents** — the defect was a
success report over an unchanged tree, so an exit-code assertion would have proved nothing. Against
the pre-fix binary they fail with:

```
Expected: not contains 'retired'
  Actual: '{ "@@locale": "es", "keep": "Mantener", "retired": "Retirado" }'

Expected: contains 'dialect/translations/es.arb'
  Actual: '✓ dialect sync --dry-run: every output is up to date.\n'
```

The orphan in those tests is not hand-seeded bytes: the fixture puts the retired key in the
translation only, and the first `sync` writes it into the output itself. That is the loop being
reproduced rather than described.

Then the reported case end-to-end, `en` → `vi`, with the key named in the report: refusal → dry-run
→ prune → `✓ dialect check: no issues`, with `wordSheetTitle` gone from both
`dialect/translations/vi.arb` and `lib/l10n/app_vi.arb` and `homeTitle` untouched. Full suite: 448
passing.

### What was deliberately not changed

- **Deleting a key from the generated output alone is still silently reverted by the next sync.**
  The report confirms this behaviour is correct and it is — that is what "generated" means.
- **The orphan refusal still refuses.** Nothing became automatic.
- **No new rule for "key in `dialect/translations/`, absent from the source".** It is tempting, and
  it is the invisible version of this bug on a project whose platforms *do* filter by namespace —
  there the key never reaches an output, so `OutputScan` never sees it. Today sync reports it, badly,
  as `skipped N key(s) without @key.namespace`. That is a real second finding, but it is a new rule
  with its own severity and `--fix` questions, not this fix's tail. Filed here so it is not lost.

---

## C · `check --fix` alphabetises, which makes range edits unsafe

Correctly filed as a trap rather than a bug — sorting is the point of `--fix`. The cost was real:
a scripted *delete the text between key A and key B* silently took `wordSheetWhereItTurnsUp`, which
sorted between them. It surfaced in seconds only because `--prune` listed **two** dropped keys where
one was expected.

The audience for this is explicitly AI agents editing ARB files, so the line went where an agent
reads:

- `templates/agents_md_section.md` — the section `dialect init` writes into a project's `AGENTS.md`.
- `templates/translate_plan.md`, §4 "Where to write" — the file `dialect translate` hands an agent.
- `README.md`, beside the `dialect sync` details block.

One sentence each: **edit these files by key, never by line range.**

`--prune` naming every key it drops is what made this visible, so that listing is unchanged — the
new report keeps naming every key, it just sorts them into what actually happens to each.

---

## 3 · Nothing tells you how to run `dialect`

The consuming project documented the *flow* correctly (`check --fix` → `sync` → `flutter gen-l10n`)
and never said how the binary arrives. In a Dart repo the first guess is `dart run dialect`, which
fails with `Could not find package "dialect"`. Their README line is theirs to fix; the package's
half is that nothing on the path a developer actually walks says it.

Checked and corrected:

- **`README.md` Install section** — the heading now carries the line rather than assuming the reader
  started at the top of the file: standalone CLI on PATH, not a package dependency, no
  `dart run dialect`.
- **`templates/agents_md_section.md`** — same line, first thing after the "this project uses
  Dialect" sentence. This is the one that matters: it is what a *future* session on a fresh clone
  reads, and the case in the report was exactly that.
- **`templates/init_plan.md`** — deliberately left alone. `dialect init` wrote it, so the binary
  demonstrably exists by the time anyone reads it.

---

## I · The pre-push hook's `command -v dialect` guard

Context only; no code change was expected and none was made. Recorded because the "is the binary
installed and current" question is partly ours.

**The "current" half already ships.** `toolchain.min_version` in `dialect.yaml` plus the
`toolchain_version` rule is exactly the affordance — an error, not a warning, on purpose. MaiSay
already pins `1.2.0`, so any `dialect check` there answers "current" today.

**The "installed" half is a shell question, not a CLI one.** A binary that is absent cannot report
its own absence; `command -v dialect` is the right test and the hook already runs it. What the hook
does with the answer — `echo` a skip line versus `fail` with the install command — is the project's
call, and with GitHub Actions paused there it is the only gate. Nothing in this package would
improve it, so nothing was built on spec.
