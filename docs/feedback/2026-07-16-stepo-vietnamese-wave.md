# Dialect — Stepo Vietnamese wave, Phase 0 (preflight)

Run context: I'm Claude Code (Opus 4.8), doing the preflight for Dialect's
first real project — localizing [Stepo](https://stepo.app) (a Flutter app,
~500 `Text(` call sites) from `en` to `vi`. This log covers **Phase 0 only**:
the five defects the handoff listed, plus what running them turned up. Stepo
extraction (Phases 1–2) has not started yet.

The wave's rule is that Dialect is ours, so friction is product signal rather
than an obstacle to route around. Everything below is written in that spirit.

---

## TL;DR

Four of the five listed defects were real. **Two were not what they looked
like** — the capability already shipped and only the docs were wrong, which is
arguably worse, because the docs are what people believe.

| # | Listed as | Actually |
|---|---|---|
| 1 | Version skew | Real. Global binary was `1.0.3`, repo `1.1.0`. |
| 2 | `init_plan.md` omits `generate: true` | Real **as a doc gap** — `init` already writes the flag itself. |
| 3 | Locking only works from the dashboard | **Not true.** File locking works today; the hint and the example were wrong. |
| 4 | README overstates the executable | Real. `--auto` and S3/R2 both advertised, neither built. |
| 5 | `init` clobbers `AGENTS.md` | **Not true.** It appends correctly. Verified against Stepo's real files. |

Plus one defect nobody listed (D6 below), found only by running the plan
verbatim instead of reading it, and one **design question for the PO** (Q1)
that I did not act on.

---

## Q1. Design question — hand-locking opts a key out of staleness forever

**This is the one thing I want a ruling on.** I did not change it.

The two lock paths are not equivalent:

- **Dashboard lock** (`strings_route.dart`) stamps `source_hash` when it
  locks. The entry stays tracked: when the English source later changes, the
  stored hash mismatches and `stale_translation` fires.
- **File lock** (hand-written `"locked": true` in a `@key` block) has no hash.
  `normalizeTranslation` deliberately skips locked entries
  (`freshness.dart:53`, "Locked entries are left to the lock/unlock flow —
  never auto-stamped"), so the entry never gets one. And `isStaleEntry`
  returns false when `stored == null`. So a hand-locked entry is **silently
  exempt from staleness detection for the rest of the project's life.**

That matters because we are now telling people (correctly) that file locking
is a first-class, git-friendly path. If they take that advice, they opt those
keys out of the very loop that makes Dialect trustworthy — and nothing tells
them.

Concretely for Stepo: `settingsEmail`-style loanwords (`Email`, `On air`) are
exactly what we'll hand-lock in Vietnamese. If the English source behind one
of them changes, we would never hear about it.

Worth noting the current behavior is *coherent* for the dashboard flow, where
the lock action stamps the hash at lock time. There is just no equivalent
moment for a hand-written lock — `check --fix` is the only pass that sees it,
and it is currently told to keep its hands off.

**My recommendation** (not applied — it contradicts a documented intent, so
it's the PO's call, per the wave's "never guess at package design" rule):
have `normalizeTranslation` stamp `source_hash` on a locked entry that has
none. It only touches entries that are invisible today; a dashboard-locked
entry already has a hash, so `hash == null` is false and it is untouched. The
semantics read cleanly: "a human locked this against *this* English."

The risk of the current behavior is silent. The risk of the change is a
one-time wave of staleness warnings on projects that hand-locked against older
English — which is information they should have had all along.

Blocking? **No** — Stepo locks nothing until Phase 4. But it wants a ruling
before then.

---

## Defects fixed (with regression tests)

### D1. Version skew — global binary was three patch versions behind

`~/.local/bin/dialect` reported `1.0.3`; the repo was `1.1.0` with a further
untagged v1.2 commit. Nothing surfaces this: `dialect --version` tells you
what you have, not what you should have, and there's no reason to suspect it.
An agent that trusts whatever `dialect` is on PATH runs a binary that predates
the very features it was told to use.

Rebuilt from HEAD and reinstalled. Verified `dialect --version` → `1.1.0`.

**Idea:** `dialect --version` could print the build commit
(`1.1.0 (a2ba01a)`). For a tool distributed as a compiled binary and developed
in the same repo you're standing in, the gap between "installed" and "HEAD" is
invisible and will bite again.

**Small trap for anyone hand-installing a dev build:** `cp build/dialect` over
an existing `~/.local/bin/dialect` gets the new binary **SIGKILLed** on macOS
(exit 137) — overwriting in place invalidates the code signature. `rm` first,
or `mv`. `install.sh:125` already uses `mv`, so real installs are fine; only
the dev path in `CLAUDE.md` §8 hits it, and that section doesn't mention
installing over the global binary at all.

### D2. `init_plan.md` never mentioned `flutter: generate: true`

Real, but not in the way it reads: **`dialect init` already adds the flag**
(`init.dart:295-315`, and it reported `pubspec.yaml (added flutter: generate:
true)` on my run). The plan was simply silent about it while step 1.5 told the
agent to run `flutter pub get` and expect `AppLocalizations` to appear —
which only happens *because* of the flag.

So the fix is a "verify this is present", not an "add this" — writing it as
an instruction would have had agents duplicating a key `init` already wrote.
Fixed, and the plan now says what to do in the unusual case where `init` skips
it (its guard is a regex over any indented `generate:`).

### D3. Locking already worked from files — the hint and the example lied

The handoff asked me to *make* file-based locking work. It already does, and
has: `arb_parser.dart:171` reads `locked`, `arb_writer.dart:102` emits it,
`freshness.dart` preserves it through `--fix`, `source_equality.dart:40`
honors it, and `source_equality_test.dart:66` has covered it all along.

The actual defects were:

1. **The hint said the wrong thing.** "lock the entry via the dashboard" —
   the one path that *isn't* available to the person reading CI output. Now
   it names the file: ``add `"locked": true` to the `@settingsEmail` block in
   this file, or lock it in `dialect serve` ``.
2. **The canonical example failed the canonical check.** `settingsEmail` is
   deliberately `Email` in Vietnamese (a loanword — the 2026-05-24 pilot log
   flagged this exact key as an intentional source-equal warning, and it was
   never resolved). Locked it in `vi.arb`.
3. **Nothing tested `examples/`.** That's the root cause — the example could
   rot for two months because no test ever ran it. Added
   `test/examples/canonical_example_test.dart`, pinning both halves of
   "canonical": it passes `--strict`, and it is already in the shape `--fix`
   produces, so a reader who runs `--fix` on it gets no diff.

Note `--fix` also stamped `source_hash` across the example's translations —
it had never been normalized. That's committed too; the example now
demonstrates provenance instead of omitting it.

I left the `stale_translation` hints pointing only at `dialect serve`, and
that is deliberate: per Q1, hand-locking genuinely does *not* resolve
staleness (the mismatched hash survives), so pointing people at the file there
would be advice that doesn't work.

### D4. README claimed things the binary refuses

- `dialect translate` was listed as `v1.0` with "(`--auto` for direct LLM
  call)" in the description — but `translate.dart:86` answers "`--auto` is not
  available yet." The status was shipped; the feature was not. `--auto` now
  has its own row marked `planned`, so it can't borrow the status of the
  command that does ship.
- `dialect publish` advertised "upload to S3/R2/git/local". Only `local`
  exists (`publish.dart:98` — "The `s3` target is not built yet"); `git` was
  never a thing. Rows now say `local`, with a note on the S3/R2 gap.
- The Status column silently mixed two meanings: `v1.0` = shipped in 1.0,
  `v1.3` = hoped for in 1.3. Added a legend, and marked publish/pull as
  `in main, unreleased` — true, since they're one commit past the `v1.1.0`
  tag and no released binary has them.

Guarded with `test/readme_claims_test.dart`, which reads the *code* and fails
the README against it. When `--auto` or the S3 target lands, the test skips
itself with a note to update the row — so the guard retires cleanly instead of
becoming a chore.

### D5. `init` and `AGENTS.md` — not a defect

Already correct (`init.dart:182-218`): prefers `AGENTS.md`, falls back to
`CLAUDE.md`, appends when the section is missing, no-ops when present, never
overwrites.

Verified against Stepo's real files as the handoff asked (both exist there —
a 288-byte `AGENTS.md` pointing at a 7.4 KB `CLAUDE.md`). `CLAUDE.md` came
back byte-identical; `AGENTS.md` kept its original bytes with the section
appended.

The one real gap: **no test covered both files existing at once**, which is
Stepo's exact shape and probably common (Codex + Claude in one repo). Added
it, asserting the file that wasn't chosen comes back byte-identical.

### D6. The plan produced an analyzer warning (not listed — found by running it)

The handoff asked me to prove `init → sync → gen-l10n → build` against current
stable Flutter. Doing it verbatim in a scratch app on **Flutter 3.41.9** found
one thing reading never would:

Plan step 1.3 said to add **two** imports to `main.dart`:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';  // ← unused
import 'package:<pubspec_name>/l10n/app_localizations.dart';
```

The first is dead. `AppLocalizations.localizationsDelegates` already bundles
the global Material/Cupertino/Widgets delegates, and the generated file
imports `flutter_localizations` itself. So following the plan exactly yields:

```
warning • Unused import: 'package:flutter_localizations/flutter_localizations.dart'
        • lib/main.dart:2:8 • unused_import
```

Small, but it lands on step one of the onboarding path we pitch as "one
command + one chat message", in a project whose CI probably gates on
`flutter analyze`. Removed the import from the plan and added a line saying
why it's not there (the package still belongs in `pubspec.yaml`, just not in
`main.dart`), so nobody helpfully adds it back.

**Full path verified on Flutter 3.41.9:** `init` → deps → `l10n.yaml` →
`dialect sync` → `flutter pub get` (which *did* run `gen-l10n` and write
`lib/l10n/app_localizations.dart` — confirming `generate: true` works and
that non-synthetic output is the current default) → `flutter analyze` clean →
`flutter build bundle` exit 0.

---

## What worked well

- **`dialect init` is genuinely one command.** It detected Flutter, scaffolded,
  wrote the plan, appended to the right agent file, patched `pubspec.yaml`, and
  told me exactly what it touched — each line of that report was true, which is
  not a given.
- **The `--fix` → `sync` → `check` loop is fast and deterministic.** Sub-second
  on the example, idempotent, and "every ARB is already canonical" is a
  satisfying thing to be told.
- **State metadata surviving `--fix` is the right call.** `locked` and
  `source_hash` are properties of the *value*; descriptive metadata belongs to
  the source. That split held up under everything I threw at it.
- **The 2026-05-24 pilot log's B1/B2 are both fixed** — the import path is
  right and the `intl` pin is gone. Following the plan on current stable now
  gets you a building app, which it explicitly did not two months ago.

---

## Scoreboard

`dart analyze` clean. `dart test`: **264 passing** (259 before; +5 from this
pass — 2 example, 1 init, 2 README). Every new test mutation-verified: I broke
the thing it guards and watched it fail, then restored.

— Claude (Opus 4.8)
