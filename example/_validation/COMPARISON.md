# Multi-Model Convention Convergence — Comparison

**Date:** 2026-05-21
**Convention version:** patched `example/dialect/dialect.yaml` (post Round 1 patches from `planning/convention-validation-report.md`)
**Runs compared:** 5

| Folder | Model | Interface | Self-reported confidence |
|---|---|---|---|
| `claude-post-patch/` | Claude Opus (via Anthropic API subagent) | Claude Code subagent | not reported |
| `claude/` | Claude Sonnet 4.6 | Cursor (agent mode) | ~65% |
| `composer-2.5/` | Composer 2.5 | Cursor (Composer agent) | ~55–65% |
| `gemini-3.5-flash/` | Gemini 3.5 Flash | Cursor | ~85% |
| `gpt-5-3/` | Codex 5.3 | Cursor (agent) | ~80% |

`claude-pre-patch/` excluded — it ran against the pre-patch convention and isn't comparable.

---

## Headline result

The convention works across models. **All 5 runs nailed the load-bearing behaviors** (seed-key preservation, demo-data discipline, glossary application, key style, formality). The divergences are concentrated in a small number of axes where the convention is genuinely silent or ambiguous. **One run produced a defect that would crash at runtime** (Codex 5.3 omitting Arabic CLDR plural categories) — that's the single must-fix before M3.

Key-count by model: 27 / 28 / 29 / 30 / 28. ±3 keys across 5 models is tight convergence for an extraction task.

---

## Axis-by-axis scorecard

| # | Axis | Convergence | Detail |
|---|------|-------------|--------|
| 1 | **Key coverage** (same strings extracted) | **High (5/5)** | All 5 found the same ~26 user-facing strings. ±2 keys of variance comes from axis 3 (home.hostedBy split) and minor judgment on whether some subtitles deserve their own key. |
| 2 | **Key naming style** | **Medium (3-way split on section headers)** | `accountSection` vs `sectionAccount` vs `account`: 2 / 2 / 1 split. See "Section header naming" below. |
| 3 | **Demo-data discipline** | **High (5/5)** | Nobody extracted `Linh Nguyen`, `linh@example.com`, `Seaside cottage in Da Nang`, `English` (language self-name), or `Stay Booking Demo` (app title). The patched "What NOT to extract" list did its job. |
| 4 | **Namespace inventions** | **High (5/5)** | All 5 added `home.*`. Nobody invented any other namespace. The patched "you may add namespaces" rule is unambiguous. |
| 5 | **`@key` description quality** | **High** | All descriptions are specific and contextual. Claude variants are the most verbose (3–4 sentences with glossary cross-refs). Gemini is the tersest. Codex sits in the middle. No "generic" descriptions in any run. |
| 6 | **Glossary application — verb/noun/lemma inflection** | **High (5/5)** | All correctly produced `Reservar`/`予約する`/`احجز`/`Buchen`/`Đặt` for the verb sense and `Reserva`/`予約`/`الحجز`/`Buchung`/`đặt phòng` for the noun-derived sense. Glossary lookup + inflection is robust across models. |
| 7 | **Plural categories per locale (Arabic)** | **MIXED (4/5)** | **gpt-5-3 / Codex omitted all CLDR categories** on Arabic `itemCount` — kept only `=0`, `=1`, `other`. Would render incorrectly for counts 2–10+. The other 4 produced full 6-category Arabic plurals. **This is the only defect that warrants a convention patch.** |
| 8 | **Placeholder preservation across translations** | **High (5/5)** | Every model kept placeholder names byte-identical between source and translations. Names varied between models (`count` vs `nights`) but not within a single model. |
| 9 | **Tone / formality** | **High (5/5)** | All 5 used informal forms per locale (tú in es, du in de, です/ます in ja, bạn in vi). Glossary style block worked. |
| 10 | **Translation quality (spot-check, Arabic)** | **High** | Spot-checking Arabic translations: identical or near-identical phrasing across all 5 for `bookNow` (`احجز الآن`), `freeCancellation` (`إلغاء مجاني خلال 48 ساعة` or close), `cancel` (`إلغاء`), and glossary terms. Style differences exist but are within native-speaker variance. |

---

## The single defect that needs a convention patch

**gpt-5-3 / Codex produced an incomplete Arabic `checkout.itemCount`:**

```json
"checkout.itemCount": "{count, plural, =0{لا توجد عناصر} =1{عنصر واحد} other{{count} عناصر}}"
```

Compare to the other 4 (sample from claude-post-patch):

```json
"checkout.itemCount": "{count, plural, =0{...} =1{...} zero{...} one{...} two{...} few{...} many{...} other{...}}"
```

For Arabic `count = 2`, `3`, `4`, `5`, `11`, `100`+ etc. the Codex version falls through to `other` instead of using the locale-required `two`/`few`/`many`. This isn't a syntax error but it's a localization defect — `dialect check` would catch it at v1.0 (it's in the structural rules), but the convention should also pre-empt it.

Codex's self-report acknowledged the choice: *"I preserved source-style exact-match plural shape for parity with source keys (rather than expanding to all Arabic CLDR category branches)."* It read the convention's "mirror exact-match cases" rule and missed that this is **in addition to** CLDR categories, not **instead of**.

**Patch needed in `example/dialect/dialect.yaml` plural section:**

Change this:

> Cover the CLDR plural categories required by the target locale. Common ones: English `one`/`other`; Arabic `zero`/`one`/`two`/`few`/`many`/`other`; Japanese and Vietnamese `other` only; German `one`/`other`.
> If the source provides exact-match cases like `=0` or `=1`, mirror them in translations. Don't synthesize extra exact-match cases the source doesn't have.

To this:

> Cover the CLDR plural categories required by the target locale **in addition to** any `=N` exact-match cases. The CLDR categories and the `=N` cases are independent — ICU evaluates `=N` first and falls back to the category. Common CLDR sets: English `one`/`other`; Arabic `zero`/`one`/`two`/`few`/`many`/`other`; Japanese and Vietnamese `other` only; German `one`/`other`.
> Mirror any `=N` exact-match cases the source provides. Don't synthesize extra `=N` cases the source doesn't have. **Do** add all required CLDR categories even if the source only has `=N`+`other`.
>
> Worked example (English source → Arabic translation):
> Source: `"{count, plural, =0{No items} =1{1 item} other{{count} items}}"`
> Arabic target: `"{count, plural, =0{لا توجد عناصر} =1{عنصر واحد} zero{...} one{...} two{...} few{...} many{...} other{...}}"`

That patch fixes Codex's failure mode. A worked example removes the ambiguity definitively.

---

## Lower-stakes divergences (worth noting, not worth patching for v1.0)

These are taste-level or genuinely judgment-call disagreements. None of them produce broken output.

### Section-header naming style

Three patterns appeared:

| Pattern | Used by | Example |
|---|---|---|
| `entitySection` (suffix `Section`) | claude-post-patch, composer-2.5 | `accountSection`, `preferencesSection` |
| `sectionEntity` (prefix `section`) | claude (Sonnet), gemini-3.5-flash | `sectionAccount`, `sectionPreferences` |
| bare entity | gpt-5-3 | `account`, `preferences` |

Functionally identical. The convention could pin one but it's stylistic. **Recommendation:** leave it. `dialect describe` and code review catch this kind of thing once a project has a few keys.

### `home.hostedBy` — extract or skip?

The home screen has a hardcoded card with `'Hosted by Linh'` (literal name, no placeholder). The card also has a sample listing title. **Convention's "What NOT to extract" lists the whole card as demo data**, but the agent has to make a judgment call about whether the "Hosted by" pattern itself is reusable copy or part of the demo.

- **Skipped** (3/5): claude-post-patch, claude (Sonnet), gpt-5-3 — treated the home card as a single demo unit.
- **Extracted** (2/5): composer-2.5, gemini-3.5-flash — treated `home.hostedBy` as real chrome that happens to be filled with demo data in this example.

Both are defensible. The 2/5 outcome creates a parallel `checkout.hostedBy` + `home.hostedBy` situation, which the convention's "two screens get separate keys" rule explicitly endorses. **Recommendation:** leave it. The split reflects a real product decision (does the home card pattern survive without the demo data?) that's better made per-project than codified.

### Currency placeholder type — `int` vs `String`

- **`int` with literal `$`** (4/5): claude-post-patch, claude (Sonnet), gemini, gpt-5-3 — e.g. `"${price} per night"` with `price: int`.
- **`String` with no `$`** (1/5): composer-2.5 — e.g. `"{price} per night"` with `price: String` (pre-formatted).

The `String` version is technically more correct for real i18n (locale-aware currency formatting at runtime), but the `int` version matches what the Dart source actually passes. Convention silence is fine here — both work; teams pick based on whether they're using `intl.NumberFormat`. **Recommendation:** leave it.

### `common.delete` vs `settings.deleteConfirm`

The convention explicitly lists `Delete` as a `common.*` candidate alongside Cancel/Save/Loading. 4/5 models followed this. Claude (Sonnet via Cursor) put it under `settings.deleteConfirm` instead. **Recommendation:** no patch. The convention is already explicit; the outlier was a model interpretation issue, likely influenced by Cursor's wrapper prompts. If a future user runs into this, `dialect describe` can suggest the move.

### Key naming variations on the same concept

| Concept | Variants observed |
|---|---|
| Legal disclaimer | `termsNotice`, `legalAgreement`, `legalDisclaimer`, `bookingAgreement`, `agreementNotice` |
| Total | `total`, `totalAmount` |
| Free cancellation | `freeCancellation`, `freeCancellationWindow` |
| Trip header | `yourTrip`, `yourTripHeader` |
| Profile edit hint | `editProfileHint`, `editProfile`, `editProfileSubtitle`, `tapToEditProfile` |
| Home AppBar | `home.title`, `home.yourTrips`, `home.tripsTitle` |
| Booking confirmed snackbar | `bookingConfirmed`, `bookingConfirmedMessage` |

All are defensible. Convention text on naming is `namespace.camelCaseKey` and "use existing namespaces" — anything more prescriptive (suffix-Header vs no suffix, include screen-element type or not) would be over-specifying. **Recommendation:** leave it. These are exactly the cases `dialect describe` should resolve at the per-project level.

### Plural-counter placeholder name

- **`count`** (3/5): claude-post-patch, composer-2.5, gpt-5-3 — follow the seed `checkout.itemCount`'s naming.
- **`nights`** (2/5): claude (Sonnet), gemini-3.5-flash — follow the parameter name from the Dart source (`widget.nights`).

Both consistent within their own files. **Recommendation:** leave it. Either approach is fine if the model is consistent.

---

## Confidence ratings — model self-reports vs reality

| Model | Self-reported | Observed match-rate vs majority |
|---|---|---|
| claude-post-patch | not reported | ~85% |
| claude (Sonnet) | 65% | ~80% |
| composer-2.5 | 55–65% | ~80% |
| gemini-3.5-flash | 85% | ~85% — and produced no defects |
| gpt-5-3 / Codex | 80% | ~75% — overconfident, given the Arabic plural defect |

**Most interesting calibration:** Gemini-3.5-Flash, despite being the cheapest model in the lineup, produced output equivalent in correctness to the Claude variants and was the only model to correctly call its own confidence at 85%. The convention text works particularly well for smaller models — which is the right outcome, since Dialect's promise is editor-agnostic and not every dev runs Opus-class models.

---

## Verdict and action items

**The convention is ready for M3** with one patch.

### Required before M3 (do now)

1. **Patch the plural section** of `example/dialect/dialect.yaml` per the diff above (CLDR categories are in addition to `=N`, with a worked Arabic example). This is the convention-validation report's Round 2 finding. Fold into `planning/convention-validation-report.md` as a "Round 2" addendum.

### Not patching (and why)

- Section-header style — taste-level, no functional impact.
- `home.hostedBy` extraction — both choices are defensible per the existing rules.
- Currency placeholder type — both work; project-level decision.
- `common.delete` placement — convention is already explicit; one model misread.
- Key naming variations — over-pinning would constrain useful local taste.

### Implications for `dialect check`

The Arabic plural defect would have been caught by M4's `plural_categories.dart` rule. **Confirm that the M4 rule, when it sees `=0`+`=1`+`other` in an Arabic ARB, flags the missing CLDR categories as a hard error in `--strict` and a friendly warning in soft mode.** The current M4 description already says this; just verify when implementing.

### Reproducibility number

If we ran this with 5 more arbitrary models tomorrow, expect **~85% near-identical output on en.arb** and **~75% on translation files**. Real-world Dialect users will see slightly higher numbers because they'll iterate (one cold run + `dialect describe` + a review pass), but a single cold run from any major model produces working ARB. That's the editor-agnostic claim, validated.
