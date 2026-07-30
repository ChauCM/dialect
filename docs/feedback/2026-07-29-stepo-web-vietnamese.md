# Dialect — Stepo's third stack: a SvelteKit site in Vietnamese

Run context: I'm Claude Code (Opus 5), acting as Dialect's maintainer while adding
Vietnamese to [stepo.app](https://stepo.app), the SvelteKit front end for
[Stepo](https://stepo.app). Stepo's canonical ARB already fed a Flutter app and an
ASP.NET backend; this wave made a website the third consumer of the same source.

The question that started it was "can Dialect support a SvelteKit front end at
all", which the docs answered wrongly. The answer is yes, with no new adapter and
no new code — and finding that out surfaced one real product defect, one gap in
the convention, and one latent data-loss trap in a real project.

---

## TL;DR

| # | Finding | Verdict |
|---|---|---|
| 1 | `sync`'s excluded-namespace warning is noise on any multi-platform project | **Fixed.** Warns only about namespaces reaching NO platform. 4 tests. |
| 2 | Docs said web was out of scope; that was a category error | **Fixed.** `platforms-frontend.md` has a real web section; struck from the v2.0 adapter list. |
| 3 | The convention never said long-form documents aren't keys | **Fixed** in `templates/dialect.yaml`. |
| 4 | The `<b>` tag convention becomes an injection surface on the web | **Documented** as a normative escaping rule. |
| 5 | The non-destructive guard earned its keep, twice, on a real repo | Working as designed. Log below. |

No adapter was written. No CLI feature was added. The web integration is
`format: icu-json` plus about forty lines in the consuming app.

---

## 1. The warning that fires when nothing is wrong

`dialect sync` on Stepo, with everything correctly configured:

```
⚠ flutter: skipped keys in namespace(s) not listed in `platforms.flutter.namespaces`: landing, push, web
⚠ backend: skipped keys in namespace(s) not listed in `platforms.backend.namespaces`: auth, blocking,
  comment, common, composer, editProfile, feed, following, journey, landing, moderation, nav,
  notification, onboarding, profile, recognition, report, search, settings, step, upgrade, web
⚠ web: skipped keys in namespace(s) not listed in `platforms.web.namespaces`: auth, blocking, comment,
  common, composer, editProfile, feed, following, journey, moderation, nav, notification, onboarding,
  profile, push, recognition, report, search, settings, step, upgrade
  hint: add these namespaces to `platforms.<p>.namespaces` in dialect.yaml, …
```

Every line of that is correct behaviour being reported as a problem. The
warning was written for the single-platform case — `namespaces: [common]`, the
dev adds `checkout` keys, sync silently drops them — where it is genuinely
useful. It does not survive contact with the shape the product is *for*: three
platforms partitioning one source, each deliberately excluding most of it.

The failure mode is not cosmetic. Output that is loud when everything is fine
teaches people to stop reading it, and `dialect sync`'s output is where the
orphan-key refusal appears.

**Fixed** by asking the question that actually matters: is there a namespace no
platform claims, whose keys are therefore emitted nowhere?

```
⚠ 1 namespace(s) reach no platform, so their keys are emitted nowhere:
    landing  —  43 key(s)
  hint: add each one to a `platforms.<p>.namespaces` list in dialect.yaml, …
```

Coverage is computed over every *configured* platform, not the ones a given run
touched, so `--platform backend` does not report the app's namespaces as
homeless. An unfiltered platform (`namespaces: []`) means nothing can be
unrouted, so the warning cannot fire at all.

The old warning **had no test coverage whatsoever** — that is how it shipped and
survived. The new one has four, including the `--platform` case.

---

## 2. "React web is secondary; i18next covers their needs"

`platforms-frontend.md` listed React Web and React Native as *out of v1 scope*,
and the summary table gave the reason: those teams are already served by
i18next.

That is a correct answer to a question nobody in our audience is asking. It
answers **"should a web-only team adopt Dialect?"** — no, obviously not. The
question Stepo asked is **"our Flutter app and our backend already read one
source; can the website read it too?"** That is not a secondary use case, it is
the thesis. A reader hitting that table would have concluded the answer was no,
and gone and installed a second, unrelated localization system for the same
strings.

Corrected, and the correction is worth more than the addition: a wrong scope
notice in the docs is worse than a missing one, because people believe it.

**What web integration actually is:**

```yaml
platforms:
  web:
    output: src/lib/locales/
    format: icu-json
    namespaces: [web, landing]
```

Two things I expected to need and did not:

- **A typed-accessor generator.** Flutter gets compile-time key safety from
  `gen-l10n`; I assumed the web needed an equivalent. It does not —
  `keyof typeof en` over the emitted JSON gives the full key union, and
  TypeScript even suggests the correction:

  ```
  error TS2820: Type '"navFeeed"' is not assignable to type '"navFeed" | …'.
  Did you mean '"navFeed"'?
  ```

  Shipping a `.d.ts` emitter would have been Dialect reimplementing a compiler
  feature. Two lines in the consuming app instead.

- **An ICU formatting dependency.** `Intl.PluralRules` is in every JS runtime
  including edge workers, and it is CLDR-correct for every locale the platform
  knows. A renderer covering `{placeholder}`, `plural`, `selectordinal`,
  `select`, `#` and ICU's reduced quoting is one small file with no dependency.
  `intl-messageformat` stays the right call for date/number skeletons.

Both belong in the docs, not in the binary. **Web frameworks are now struck
from the v2.0+ sponsored-adapters list** — verified unnecessary rather than
deferred, which is the good kind of scope cut.

---

## 3. The convention never said a policy isn't a string catalogue

`templates/dialect.yaml`'s "What NOT to extract" list is good and specific:
personal names, currency amounts, language self-names in a picker, demo
content. It says nothing about long-form documents.

Stepo has six of them — privacy, terms, community guidelines, child safety,
copyright, data deletion — at 200 to 250 lines of prose each. An agent told to
"extract all user-facing strings" and handed that list would have shredded a
privacy policy into eighty keys, *correctly following the instructions it was
given*. The result is meaningless key names, diffs nobody can review, and
clauses that drift between locales. For a document with legal effect, a drifted
clause is worse than no translation.

Added to the template with the reasoning, plus the second question to ask after
"would this change for a different user?": **is this a sentence in a UI, or a
section of a document?**

Stepo's ruling, for the record: the documents stay English in every language,
the chrome around them is translated, and the page says so plainly. That is a
product call, but the convention should have made the shape of the call
obvious, and it didn't.

---

## 4. `<b>` is free on Flutter and load-bearing on the web

The [rich-text convention](../platforms-frontend.md#rich-text-inside-one-sentence)
keeps a styled run inside one translatable sentence by putting an inline tag in
the value:

```json
"landingFirstStepStartedWith": "<b>{name}</b> started with this journey"
```

On Flutter those tags go through a `TextSpan` parser that cannot execute
anything. On the web, rendering them means `{@html}` — and Stepo has 62 such
keys, many interpolating somebody else's words: a display name, a journey
title. **Our convention creates the situation, so the rule belongs in our
docs.**

The rule is *format to a stream, not to a string*: the renderer must know which
output runs came from the message (ours, trusted, may carry tags) and which
came from arguments (never ours, always escaped).

The shortcut I want to name explicitly, because it looks obviously fine and is
not — concatenate, escape the whole result, then un-escape `&lt;b&gt;` back
into `<b>`:

```
name = "<b>"   →   escaped to "&lt;b&gt;"   →   un-escaped back into a real tag
```

A visitor whose display name is literally `<b>` gets it rendered as markup.
Today that only breaks a layout. The day the tag set grows an attribute it is an
injection, and no test of the happy path would ever have caught it. Both
behaviours are now pinned by tests in the reference implementation.

---

## 5. The guard, twice, on a live repo

Worth logging because both are exactly what the non-destructive `sync` was
built for, and both fired on a real project with real users' data behind it.

**Sixty-two keys added straight to the generated Flutter ARBs.** Two commits
after the last Dialect-mediated change, someone (an agent, mid-wave) wrote keys
into `lib/l10n/app_en.arb` and `app_vi.arb` directly. A pre-1.2 `sync` would
have deleted all 62 silently. Instead:

```
✗ dialect sync: refusing to run — the generated output holds 62 key(s) that are not
  in your source (dialect/source/en.arb). Regenerating would delete them.
```

`--adopt` recovered every one, English and Vietnamese together.

**One key that lived only in the backend's generated JSON.**
`pushBodyRecognitionCompanion` was committed to
`StepoBackend/.../Locales/{en,vi}.json` and referenced by
`NotificationService.cs`, but was absent from the canonical ARB. Since
`NotificationLocalizer.Get` falls back to `?? key`, deleting it would have made
the Companion push notification render the literal string
`pushBodyRecognitionCompanion` to a real person. The orphan scan reads JSON
outputs too, so it caught that one on the same pass.

**One rough edge in the recovery, worth a follow-up.** `--adopt` writes the
recovered value into the source but cannot invent metadata, so the adopted keys
land without a `namespace`. On the very next write in that same run they are
therefore excluded from every filtered platform — which for
`pushBodyRecognitionCompanion` meant sync momentarily wrote a backend `en.json`
*without* the key it had just rescued. Supplying the namespace and re-syncing
restored it (final state is byte-identical to HEAD, nothing was lost), but the
intermediate state is alarming and a user would be right to panic. The hint
after `--adopt` already says an adopted key "still needs a
`namespace`/`description`"; it should say plainly that **until it has one, the
key is excluded from every filtered platform**, and `--adopt` should probably
not emit filtered outputs in the same pass at all.

---

## What this wave did not need

Listing this because the temptation was real at each point:

- No `svelte-json` / `paraglide` / `typesafe-i18n` adapter.
- No typed-accessor codegen.
- No per-platform `target_locales` (Stepo's web and app ship the same pair; the
  limit is noted, not built on speculation).
- No new CLI command, flag, or config key.

One warning fixed, three docs corrected. The convention did the work.
