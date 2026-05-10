# Convention Validation Report (M0)

**Date:** 2026-05-21
**Status:** ✅ Passed with iteration — convention shipped for M3 with patches.
**Tester:** Fresh general-purpose AI agent, given access only to files under `example/`. No knowledge of Dialect, no access to `docs/`, `planning/`, `CLAUDE.md`, or `README.md`.
**Target locales:** `es, ja, ar, de, vi`.

This is the M0 deliverable per `CLAUDE.md` §5 step 1 / plan-file Phase 0. Its purpose is **not** to confirm that the convention generates correct output (it does), but to expose every gap that would make two AI agents produce *different* output from the same convention. Reproducibility-between-agents is the real bar.

The patches at the end of this report are folded into `example/dialect/dialect.yaml`. **`lib/templates/dialect_yaml.dart` (built in M3) takes its canonical text from the patched `example/dialect/dialect.yaml`. Do not write that template until this report is read and reconciled with the example file.**

---

## What worked

Without follow-up prompting, the agent:

- Read the convention file, then the glossary, then the existing `en.arb`, then the Dart source. Order followed the workflow block.
- Produced keys in `namespace.camelCaseKey` form with zero exceptions.
- Did **not** rename or overwrite the four pre-seeded keys (`checkout.bookNow`, `checkout.itemCount`, `common.cancel`, `common.loading`).
- Filled `@description` and `@context` on every new key with enough specificity that a translator could work from them.
- Declared `@key.placeholders` for every parameterized string.
- Applied glossary terms correctly: `Book` (verb) → `Reservar` / `予約する` / `احجز` / `Buchen` / `Đặt`; `Host` → `Anfitrión` / `ホスト` / `المضيف` / `Gastgeber` / `Chủ nhà`; `Trip` → `Viaje` / `旅行` / `رحلة` / `Reise` / `Chuyến đi`.
- Correctly handled glossary **derivations**: "Booking confirmed" → `Reserva confirmada` (Spanish noun form), not the verb `Reservar`. This is non-trivial — the convention doesn't spell it out but the agent inferred it from the glossary's `meaning` field.
- Produced correct ICU plural categories per locale: Arabic 6-form (zero/one/two/few/many/other), German 2-form, Spanish 2-form, Japanese 1-form, Vietnamese 1-form. No invented or missing categories.
- Preserved every placeholder name byte-identically across all translations.
- Sorted keys alphabetically in both source and all translation files.
- Used the per-locale formality prescribed by `glossary.yaml` (tú / du / です/ます / MSA-informal / bạn).
- Omitted `@key` metadata blocks from translation files (standard Flutter ARB practice).

**These are exactly the high-value, hard-to-get-right behaviors the convention exists to enforce.** The convention works.

---

## Gaps surfaced by the agent's self-report

These are not "the agent got things wrong" — the agent's output is good. These are places where a *different* agent could reasonably make a *different* defensible call. That's a reproducibility problem and the convention needs to close it.

| # | Gap | Why it matters | Resolution |
|---|-----|----------------|------------|
| 1 | **Demo/sample data policy.** Are hardcoded personal names, emails, language self-labels, and demo listing titles user-facing copy or data? Agent extracted some, skipped others. | Single biggest source of cross-agent divergence. | Add explicit section: "What NOT to extract" listing personal names, email addresses, currency amounts, language self-names, dates/times, and demo placeholder data. |
| 2 | **`platforms.<platform>.namespaces` semantics — allowlist or default?** Agent introduced a `home` namespace not in the list, on the strength of the freeform "introduce a new one only when no existing namespace makes sense" rule. | Two agents could legitimately disagree on whether to invent `home` or shove the strings into `common`. | State explicitly: the list is the set of namespaces that **sync** to that platform; the agent is free to introduce additional namespaces in `en.arb` and the developer adds them to the list before next `dialect sync`. |
| 3 | **Identical strings in different namespaces — share or split?** Agent split `"Hosted by {hostName}"` into `checkout.hostedBy` and `home.hostedByShort`. | Some teams prefer one shared key per surface form; others prefer per-screen keys for independent future evolution. | State explicitly: **prefer per-screen keys**; if two screens currently render the same string, that is a coincidence, not a guarantee. Shared keys go in `common.*` only when the string is logically shared. |
| 4 | **`@key` metadata in translation files — mirror or omit?** Agent omitted (correct, matches Flutter convention) but the convention was silent. | A literal-minded agent could mirror metadata into every translation file, doubling file size and creating drift. | State explicitly: translation files contain only `@@locale` plus key/value pairs. Metadata lives only in the source ARB. |
| 5 | **Sort algorithm.** Agent used lowercase-aware lexicographic on the full key string. The convention says "alphabetically" without specifying case sensitivity, collation, or `@@locale` placement. | Two agents could produce diff-noise output (one capital-first, one lowercase-first) and `dialect sync` would have to reconcile every time. | State explicitly: byte-wise lexicographic on the key string (dot is an ordinary character). `@@locale` is always the first entry. Sort metadata `@key` entries immediately after their key. |
| 6 | **Currency symbol placement.** Convention says "don't translate currency symbols" but is silent on positional reordering. | Some locales put the symbol after the number; some use a different decimal separator. | State explicitly: **match the position used in the source string**. Locale-specific currency formatting is a runtime number-formatting concern, not a translation concern. |
| 7 | **Glossary inflection and derivation.** When does the verb form apply vs. a derived noun? | Naively applying `Book → Reservar` to "Booking confirmed" would produce `Reservar confirmado`, which is wrong. | Add a note: glossary `term` is the canonical lemma; agents should use the appropriate inflection/derivation in target language. The glossary `meaning` field is the source of truth for which sense applies. |
| 8 | **Language self-names.** A `_language = 'English'` state field is user-facing but doesn't translate per-locale (the Spanish UI still says "Español", not the Spanish translation of "English"). | A naive extract pulls it; a careful one skips it. | Covered by gap 1's "do not extract" list, with an explicit example. |
| 9 | **`$` literal vs ICU/JSON escaping.** ICU treats `$` as ordinary text; JSON has no `\$` escape. Source `'\$${price}'` in Dart becomes `"${price}"` in ARB. | A confused agent might write `"\${price}"` or `"\\${price}"`, breaking the string. | Add a short "Escaping" subsection: `$` is ordinary text in ARB; only `{` and `}` and `'` need ICU escaping (`{{`, `}}`, `''`). |
| 10 | **Product/domain summary.** The agent had to reverse-engineer "short-stay rental app" from the glossary's `meaning` fields. | Without a domain line, a naive agent could translate `Trip` as a corporate business trip or `Host` as a computer server, despite the glossary. | Add a single `project:` block at the top of `dialect.yaml` with a one-line product description. |
| 11 | **`=0` plural coverage.** Convention says "extras are harmless" but doesn't mandate covering `=0`. Agent covered `=0` inconsistently across keys. | Inconsistent coverage is a soft signal but creates drift. | State explicitly: cover every category the locale's CLDR rules require, plus `=0` and `=1` exact-match cases when the source provides them. Don't synthesize `=0` if source doesn't have it. |
| 12 | **Policy-document proper nouns.** "House Rules" and "Cancellation Policy" — translate or treat as named documents? Agent translated them as descriptive phrases. | Strict reading of "don't translate brand names" could go either way. | Out of scope for the convention spec. Project glossaries should list specific policy-document names if they should remain in English. Note in the convention header. |

---

## Patches applied to `example/dialect/dialect.yaml`

The patched file at `example/dialect/dialect.yaml` adds:

1. A `project:` block at the top with a one-line product summary (resolves gap 10).
2. A "What NOT to extract" subsection in the AI-instructions header (resolves gaps 1 and 8).
3. An "Escaping" subsection (resolves gap 9).
4. An "Identical strings in different namespaces" subsection (resolves gap 3).
5. Explicit allowlist-vs-default semantics for `platforms.*.namespaces` (resolves gap 2).
6. Explicit sort algorithm (resolves gap 5).
7. Explicit metadata-only-in-source rule (resolves gap 4).
8. Currency-position rule (resolves gap 6).
9. Glossary-inflection note (resolves gap 7).
10. Plural-category coverage rule (resolves gap 11).

Gap 12 is intentionally not codified — projects with named policy documents should add them to their own glossary.

---

## Decision: do we re-run a second cold-agent pass?

**No, not for v1.0.** Cost-benefit doesn't pencil out:

- The convention's *output* is correct. Patches address *reproducibility*, not correctness.
- A second pass would surface a smaller set of new gaps. The marginal value drops fast.
- The convention is text. It is cheap to iterate post-launch from real-user signal (issues, PRs).
- M3 needs to start; sequencing said M0 → M3 is the highest-leverage handoff, not "M0 iterated to perfection."

If a real user reports the convention is ambiguous in a way this report didn't catch, that becomes a v1.0.x patch.

---

## Action item for M3

`lib/templates/dialect_yaml.dart` MUST take its content from `example/dialect/dialect.yaml` after these patches land — not from `docs/architecture.md` (which is older) and not from a freshly written template. The example file is the canonical source after M0.

---

## Round 2 — Multi-model convergence test (2026-05-21)

The Round 1 single-Claude validation said "the convention is good enough to ship; the gaps are about reproducibility-between-agents, not correctness." Round 2 tested that claim empirically.

**Setup.** Ran the same M0 task with 5 models against the patched convention: Claude Opus (subagent), Claude Sonnet 4.6 (via Cursor), Composer 2.5 (Cursor), Gemini 3.5 Flash (Cursor), and Codex 5.3 (Cursor). Each model wrote to its own isolated folder under `example/_validation/runs/<model>/` with strict input allowlisting. Full per-axis comparison is in `example/_validation/COMPARISON.md`.

**Headline.** 5/5 converged on 9 of 10 scored axes (key coverage, demo-data discipline, namespaces, descriptions, glossary application, placeholder preservation, tone, translation quality on Arabic, named-entity preservation). Key counts ranged 27–30 across models — ±3 keys is tight convergence.

**One defect that warrants a patch.** Codex 5.3 produced `"checkout.itemCount"` in Arabic as `{count, plural, =0{...} =1{...} other{...}}` — i.e. dropped all CLDR categories (`zero`/`one`/`two`/`few`/`many`) and relied on `other` for counts 2–10+. Its self-report admitted the choice: it read "mirror exact-match cases" as a substitute for, not a supplement to, CLDR categories. The other 4 runs got it right.

**Patch applied to `example/dialect/dialect.yaml` plural section.** Rewrote to explicitly state CLDR categories are required *in addition to* `=N` mirrors, and added a worked Arabic example showing both side-by-side. This is the only Round 2 patch.

**Lower-stakes divergences left unpatched** (with reasoning):

- Section-header naming style (3-way split: `accountSection` / `sectionAccount` / `account`) — taste-level, no functional impact.
- `home.hostedBy` extraction (2/5 yes vs 3/5 no, from a hardcoded demo card) — both defensible per existing rules; a real product decision.
- Currency placeholder type (4/5 `int` + literal `$`, 1/5 `String` pre-formatted) — both work, project-level call.
- `common.delete` vs `settings.deleteConfirm` (4/5 vs 1/5) — convention is already explicit; outlier was a model interpretation issue, not a convention gap.
- Naming variations on the same concept (`totalAmount` vs `total`, `legalAgreement` vs `termsNotice`, etc.) — over-pinning would constrain useful local taste; `dialect describe` resolves these per-project.

**Implications for M4.** The `plural_categories.dart` rule must flag missing CLDR categories as an error in `--strict` mode and a friendly warning in soft mode. Confirmed in M4's task description; verify during implementation.

**Final M3 action item update.** `lib/templates/dialect_yaml.dart` takes its content from `example/dialect/dialect.yaml` **after both Round 1 patches and the Round 2 plural patch** land — both are now in the file. The inputs snapshot at `example/_validation/inputs/dialect/dialect.yaml` has also been refreshed.
