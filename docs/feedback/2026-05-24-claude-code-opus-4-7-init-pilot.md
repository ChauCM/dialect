# Dialect — first-agent feedback

Run context: I'm Claude Code (Opus 4.7), running in `examples/after`. Task was
the canonical chat-first onboarding: `run dialect init and follow the
instructions`. App = the Stay Booking demo (4 files, 28 candidate strings).
Target locales = `[es, de, ja, vi, ar]` (I picked these because the locale
switcher example in the init plan listed them; you may want to be explicit
about this choice — see below).

This is honest feedback, not a complaint list. Most things worked. The
hiccups below are exactly that — hiccups — but they're load-bearing for the
"one command + one chat message" pitch, so they're worth fixing.

---

## TL;DR — top 5 things to fix or look at

1. **Init plan's Flutter import path is stale.** It says
   `import 'package:flutter_gen/gen_l10n/app_localizations.dart';` but
   modern Flutter defaults to `synthetic-package: false`, so the file
   lands in `lib/l10n/app_localizations.dart` and the right import is
   `package:<pubspec_name>/l10n/app_localizations.dart`. I wasted ~3 min
   on `uri_does_not_exist` errors before figuring this out.
2. **`intl: ^0.19.0` in the init plan won't resolve** against any
   recent Flutter SDK — `flutter_localizations` pins `intl` to `0.20.2`
   in current stable. Pub fails immediately on first `flutter pub get`.
3. **`dialect sync` with `platforms.flutter.namespaces: [...]` silently
   produced empty translation stubs.** Sync warned "skipped 29 key(s)
   without `@key.namespace`" — but translation files correctly don't
   carry `@key` blocks (the convention forbids it). The namespace filter
   needs to join translation keys against source ARB metadata. The
   workaround (`namespaces: []`) disables the feature entirely; that
   shouldn't be the only path.
4. **`dialect sync` reports "nothing to do" when it should re-emit.**
   After editing source + writing translations, sync said "every output
   is already up to date" while `lib/l10n/app_*.arb` were 3-line stubs
   from the first sync. I had to `rm` the files to force a rewrite.
5. **`flutter gen-l10n` warns "plural part overridden" on every locale
   with `=1` + `one`.** The convention explicitly tells the agent to
   include both. For most locales' CLDR `one` matches n=1 only, so the
   redundancy is real dead code. Worth refining the rule (details below).

---

## Bugs / blockers (got me stuck)

### B1. Stale Flutter import path in init plan

The plan in `.dialect/init-plan.md` says:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

That import resolves only when `l10n.yaml` has `synthetic-package: true`,
which is not the default anymore. With the plan's recommended
`l10n.yaml` (no `synthetic-package` line → defaults to `false`), the
file is emitted at `lib/<arb-dir>/app_localizations.dart` and the right
import is `package:<pubspec_name>/<arb-dir>/app_localizations.dart`.

**Suggested fix:** either set `synthetic-package: true` in the plan's
`l10n.yaml` template (one extra line), or have the plan compute the
correct import from `pubspec.yaml` name + `arb-dir`. The second is more
honest about modern Flutter behavior.

### B2. `intl` pin too low

Plan says:

```yaml
flutter_localizations:
  sdk: flutter
intl: ^0.19.0
```

…but current Flutter SDK pins `intl` to `0.20.2` transitively through
`flutter_localizations`. Pub fails with a clear version-solving error,
so it's recoverable, but it's a stumble on the very first step.

**Suggested fix:** drop the explicit `intl` constraint and let it be
pulled in transitively, or have `dialect init` detect the active
Flutter SDK and emit a compatible pin. (`flutter --version` is cheap.)

### B3. Sync drops translations when `namespaces` is configured

Setup that triggered this:

```yaml
platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common, home, checkout, settings]   # all my namespaces
```

Behavior: `dialect sync` wrote `lib/l10n/app_en.arb` correctly (source
file has `@key.namespace` per key, so the filter passed), but for every
target locale it wrote a 3-line stub with just `@@locale`. The warning
was:

```
⚠ flutter: skipped 29 key(s) without `@key.namespace`: ...
```

That's confusing because translation files MUST NOT carry `@key`
blocks per the convention. The namespace filter is reading translation
files in isolation, finding no `@key.namespace`, and dropping every
key. The right model is: when iterating translation files, look up
each key's namespace from the source ARB.

**The workaround** (`namespaces: []`) disabled the feature entirely.
That's fine for Flutter (one consolidated output), but the namespace
filter exists for adapters like iOS `.strings` (one file per
namespace). So this needs a real fix, not just the workaround.

**Suggested fix:** when filtering translation files, do
`source.namespaceOf(key)` instead of `translation.namespaceOf(key)`. If
sync wants to stay strict, also warn if a translation key has no
matching source key (which IS a real metadata problem).

### B4. Sync's "nothing to do" misreports

Repro:
1. `dialect init` → source has `commonExample`.
2. `dialect sync` → wrote `lib/l10n/app_en.arb` (1 key) + 5 empty
   translation stubs.
3. I rewrote source/en.arb with 28 keys; I wrote 5 full translation
   files in `dialect/translations/`.
4. `dialect check --fix` (clean).
5. `dialect sync` → **"nothing to do (every output is already up to
   date)"** but `lib/l10n/app_es.arb` was still a 3-line stub.

I had to `rm lib/l10n/app_*.arb` to force a fresh sync. After deletion
the warning above (B3) appeared and the stubs came back empty.

Looks like the cache key only considers source ARB mtime, not the
mtimes under `dialect/translations/` (or only considers an internal
content hash that wasn't recomputed). Either:
- include translation file mtimes in the cache check
- compare actual content rather than mtime
- add `dialect sync --force` as a documented escape hatch

The mismatch between "skipped N keys" and "nothing to do" in the same
output is the smoking gun — those two messages should not coexist.

### B5. `=1` + `one` produces gen-l10n warnings in most locales

The convention says (paraphrased): "Cover the CLDR plural categories
required by the target locale IN ADDITION TO any `=N` exact-match
cases. The two are independent: ICU evaluates `=N` first and falls back
to the matching CLDR category. You need BOTH — not one or the other."

This is correct for languages where CLDR `one` matches more than just
n=1. Russian's `one` matches 21, 31, 41, … so dropping `one` after
adding `=1` would be wrong.

But for English/Spanish/German/Arabic/Japanese/Vietnamese, CLDR `one`
matches **only** n=1. After `=1` matches, `one` is dead code.
`flutter gen-l10n` correctly warns:

```
[app_de.arb:checkoutNights] ICU Syntax Warning: The plural part
specified below is overridden by a later plural part.
    {nights, plural, =1{1 Nacht} one{{nights} Nacht} other{...}}
```

Harmless at runtime, but noisy. Three options:
- **(A)** Refine the convention: "If your locale's `one` covers values
  beyond 1 (Russian, Polish, Arabic-`one`-actually-matches-only-1),
  include both. If `one` matches only n=1, prefer `=1` and skip `one`."
  This is the most correct, and arguably the most teachable.
- **(B)** Have `dialect check` or a new `dialect lint-plurals` detect
  the overlap and offer `--fix` to remove redundant `one`.
- **(C)** Document the warning is intentional safety belt-and-braces;
  agents should ignore it.

I'd vote (A) → with (B) as the enforcement layer.

---

## Convention friction (small DX wins)

### F1. Glossary substring match misses Arabic inflection

The glossary check fires on substring presence of the prescribed
translation. Arabic's morphology makes this miss:

- `Trip` → `رحلة` (lemma), but "your trip" = `رحلتك` (ة → ت + ك). The
  stem is present but `رحلة` exactly is not.
- `Host` → `المضيف` (with `ال`), but "as a host" = `كمضيف` (loses
  `ال`). Stem present, full form absent.

Both translations are correct, idiomatic Arabic. The check throws a
warning; the convention's escape hatch is `glossary_exempt: true`,
but that's for *non-literal* uses — these are literal, just inflected.

**Suggested fix:** either ship a tiny per-glossary-entry `accepts:`
list (`accepts: ["رحلة", "رحلت", "رحلتك"]`), or relax the matcher to
match on a 3-character stem prefix for non-Latin scripts. The former
is more explicit; the latter is more magical.

### F2. Default `length_ratio` band is wrong for Japanese and Arabic

Defaults are `[0.3, 2.5]` for every locale not overridden. In practice:

- **Japanese** routinely hits 0.15–0.25× because labels collapse:
  "Settings" (8 chars) → "設定" (2 chars). Three label keys in
  Settings hit `length_ratio` warnings on first check, all legitimate.
- **Arabic plurals** routinely hit 2.6–3.0× because six CLDR
  categories pack into one string.

I added overrides in `dialect.yaml`:

```yaml
length_ratio:
  ja: [0.1, 2.5]
  ar: [0.3, 3.0]
```

…but every Flutter app shipping these locales will hit these warnings
on first translate. Worth shipping these as defaults.

### F3. Phase 1.5 smoke test feels heavyweight for small apps

The plan says: drop a `Text(AppLocalizations.of(context)!.commonExample)`
into the home screen, verify it renders, then revert. For a ≤50-string
app I skipped this — placing then ripping out a throwaway widget felt
worse than just going straight to real keys, which would themselves
exercise the pipeline. The plan could acknowledge this:

> "If you're going straight to Phase 2 in the same turn (≤50 strings),
> skip the seed smoke test — your first real key will exercise the
> pipeline."

### F4. `dialect.yaml` ships `project.name: "Your project"`

Easy enhancement: `dialect init` could look at `MaterialApp(title: '…')`
in the existing source and prepopulate `project.name`. Mine was
clearly "Stay Booking Demo"; I had to edit it manually.

### F5. `target_locales` ships empty

The init plan template has the phrase "Target locales: `(none
configured yet)`" baked in. The plan still ran end-to-end without
target locales, but Phase 2.3 (translate) had nothing to do until I
edited `dialect.yaml` myself. Either:

- `dialect init --with-locales es,de,ja` flag
- prompt during init: "what locales do you ship in?"
- or document explicitly in the plan: "Before Phase 2.3, edit
  `dialect.yaml`'s `target_locales` — Phase 2.3 will write one file
  per locale you list."

The third option is the lowest-effort + chat-first-friendly fix.

### F6. Per-key descriptions are great; project-level "what does this app do" is great; missing a per-namespace blurb

I'd love a `namespaces:` block in `dialect.yaml` where each entry can
include a one-liner:

```yaml
namespaces:
  checkout: "Booking confirmation flow — payment + agreement screen."
  settings: "User account preferences."
  home: "Trip list, top-level navigation."
  common: "Shared UI strings (cancel, save, loading)."
```

Today the namespace's *meaning* lives only in `@key.description`
ad-hoc. A blurb per namespace would let the agent disambiguate
borderline keys ("does this go in `common` or `settings`?") without
reading every existing key in that namespace.

---

## What worked really well

- **Two-phase init plan with sizing threshold (50 strings).** This is
  the right structure. The bounded Phase 1 + the conditional Phase 2
  is exactly how I'd want to be briefed. Bigger projects get a sane
  human-review pause; small projects get end-to-end.
- **`dialect check --fix`** — fast, deterministic, single command,
  clear warnings with hints. Excellent feedback loop. The hints that
  point at the right escape hatch ("add `glossary_exempt: true`", "lock
  via the dashboard") are perfect.
- **The convention encoded as YAML comments in `dialect.yaml`.** I
  read top-to-bottom once and had everything I needed. Comments are
  long, but each section earns its space. The "Worked example" for
  Arabic plurals was a specific kindness.
- **`@key.description` + glossary `meaning` together.** The "Book is a
  verb, NOT a physical book" framing in glossary + per-key descriptions
  with context cues let me get inflection right (Spanish `Reserva
  confirmada` noun form, not `Reservar confirmado` mechanical verb
  form). This is the *exact* trick that pays for itself.
- **The "What NOT to extract" list.** Saved me from extracting `Linh
  Nguyen`, `linh@example.com`, or the language self-names in the
  picker. Concrete > abstract.
- **`AGENTS.md` is a great idea.** I haven't tested its effect across
  sessions yet, but as a structural pattern it matches how Claude Code
  hydrates context.

---

## Suggestions / ideas

- **`dialect doctor`** — one command that runs `check` +
  `flutter pub get` + `flutter analyze` + `flutter gen-l10n` and
  returns a combined report. The mid-task "is everything still happy"
  check.
- **`dialect sync --force`** — explicit escape hatch when the cache
  thinks it's done but you know it isn't (and ideally fix B4 so this
  is never needed).
- **`dialect describe`** — AI-pointer that reads the source code to
  backfill `@key.description` from callsites for keys imported from
  Lokalise / older ARB files that lack metadata. (You may already
  have this — I didn't try the `import` flow.)
- **A `--dry-run` flag on `sync`** — show me what would change without
  writing. Useful when iterating on `dialect.yaml` filter config.
- **In the plan, close with a one-line dashboard pointer:**
  "Open `dialect serve` to review every translation side-by-side, lock
  cognates / loanwords (`Total` in Spanish, `Email` in Vietnamese),
  and dismiss intentional source-equal entries."
- **Make the plan re-render `target_locales` from current
  `dialect.yaml`.** Currently the phrase "(none configured yet)" is
  baked into my plan file even though I edited `target_locales`
  afterwards. Re-running `dialect init` should refresh.

---

## Outstanding warnings in this run (for your reference)

After all fixes, `dialect check` ends with 4 warnings, all intentional:

```
ar: checkoutYourTrip — glossary substring miss on رحلة (legitimate رحلتك inflection)
ar: settingsDeleteAccountDialogBody — glossary substring miss on المضيف (legitimate كمضيف form)
es: checkoutTotal — source-equal ("Total: ${amount}"; "Total" is a cognate)
vi: settingsEmail — source-equal ("Email"; common loanword in Vietnamese)
```

`flutter gen-l10n` adds 3 ICU warnings about `=1` + `one` overlap (one
per locale that has both). Harmless; see B5.

`flutter analyze`: clean.
`flutter test`: 1/1 pass.

---

## Process note

The total agent time on this task was roughly:
- Phase 1 wiring: ~3 minutes (would've been ~1 minute without B1+B2)
- Phase 2 extract: ~2 minutes (28 keys, mostly straightforward)
- Phase 2 translate to 5 locales: ~6 minutes (most of the wall-clock —
  this is where having a clean convention + glossary really pays off)
- Validate + fix sync bugs: ~5 minutes (almost entirely B3+B4)

So roughly 50% of my time was on convention work (good) and ~30% was on
CLI bugs (fixable). That ratio should drop to ~5% on the bug side once
B1–B4 are addressed.

— Claude
