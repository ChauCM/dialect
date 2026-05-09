# Competitive Strategy

Conclusions from reviewing 10 external perspectives on Dialect's design, positioning, and competitive landscape.

---

## The Real Moat: Cross-Platform Sync

The killer feature is not AI translation. Every tool claims AI translation. The feature nobody else has:

**"I added a key in my Flutter app and ran one command and my iOS `.strings`, Android `strings.xml`, and Go backend JSON all had it in 6 languages."**

Cross-platform sync from a single canonical source — Flutter, iOS native, Android native, backend services, same strings, same translations, one command — is what makes people stop scrolling. That's the demo. That's the pitch.

AI-assisted translation is the method. Cross-platform sync is the value.

---

## Target Audience (Revised)

### Who Dialect is for

Developer-led teams that:

- Ship mobile apps (Flutter, iOS native, Android native) with a backend
- Already use AI for coding and want to use it for translation
- Are frustrated by the "add a key, context-switch to dashboard, wait for translations, manually sync to backend" workflow
- Maintain multiple mobile platforms with different localization formats that constantly drift apart
- Don't have a dedicated localization ops team

### Who Dialect is not for

- **React-web-only teams.** i18next already solves their problem. Dialect adds indirection without proportional value.
- **Enterprise localization operations** with dedicated linguists, approval chains, and 50+ locales. They need Lokalise/Crowdin-class TMS features.
- **Solo devs shipping one app in 2 languages.** Overkill for day-one needs. They'll adopt later when they hit scale.

### Platform Priority

Priority is roadmap ordering. Fidelity is whether all ARB features survive the sync (ICU plurals, named placeholders, descriptions).

| Priority | Platform | Output format | Fidelity | Reasoning |
|---|---|---|---|---|
| Primary | **Flutter** | `arb` | Lossless | Home audience. ARB native. No AI-native solution exists. |
| Primary | **iOS (Swift)** | `apple-strings` + `.stringsdict` | Faithful | Terrible localization DX. No cross-platform sync solution exists. ICU plurals map to `.stringsdict` via documented CLDR mapping. |
| Primary | **Android (Kotlin)** | `android-xml` + `plurals.xml` | Faithful | Same story as iOS. ICU plurals map to `<plurals>` via documented CLDR mapping. |
| Primary | **Backend (Node, Python, C#, Go)** | `icu-json` or `flat-json` | Lossless (icu-json) / Lossy (flat-json — drops plurals) | Shared strings with all mobile platforms. Per-stack localizer template, not per-stack adapter. See [Backend Humility](#backend-humility). |
| Secondary | **React / React Native** | `i18next-json` | Faithful | RN teams already have decent tooling. ICU plurals convert to i18next plural syntax. |
| Parked | **`.resx` / `.po` as adapters** | — | Would be Lossy | Replaced by lossless localizer template approach (icu-json + drop-in `JsonStringLocalizer` for ASP.NET, JSON catalog swap for Django). We don't maintain lossy format adapters when a lossless template path exists. |

---

## Backend Humility

Dialect's cross-platform sync only works if backend teams agree to adopt it. FE teams dictating BE stack changes is always a hard conversation — and rightly so. We optimize for the backend engineer's path of least resistance.

**The principle:** Dialect outputs JSON (flat-json or icu-json). Per-stack support is a thin, lossless localizer template that plugs that JSON into the stack's native localization interface — not a new file format Dialect maintains.

| Stack | What Dialect gives the BE engineer |
|---|---|
| ASP.NET | A ~30-line `JsonStringLocalizer : IStringLocalizer<T>` template. Callsites unchanged. |
| Django | A JSON catalog backend swap (settings change, no callsite rewrite). |
| Flask / FastAPI | JSON dict loader (~20 lines). Already JSON-friendly. |
| Node.js | `i18next-fs-backend` config or trivial dict loader. |
| Go | `go-i18n` JSON loader (native). |

This means:

- **We never ask BE engineers to abandon their abstractions.** `IStringLocalizer<T>`, Django's `gettext` interface, Flask-Babel's API — these stay intact. Only the backing store swaps.
- **We never ship a lossy adapter (e.g. ARB → `.resx`) when a lossless template (ARB → icu-json → `JsonStringLocalizer`) exists.** Lossy adapters silently degrade ICU plurals and named placeholders; templates preserve them.
- **Dialect's codebase stays small.** The "per-backend support" matrix is a docs page, not adapters. Maintenance cost is near-zero. New stacks are added by writing a snippet.

The artifact a Flutter dev forwards to their BE engineer is a docs page with a copy-pasteable localizer — not a "please install this new tool and migrate off `.resx`" ask. That's what makes the cross-platform sync pitch survive contact with a real BE team.

See [Backend Platforms](../docs/platforms-backend.md) for the per-stack snippets.

---

## Relationship with i18next

Dialect is **not competing with i18next.** i18next is the React/RN runtime. Dialect is the build-time sync and validation layer that generates files i18next consumes.

The positioning:

- i18next = runtime (loads translations, resolves plurals, handles fallbacks in the browser/app)
- Dialect = build-time (canonical source, cross-platform sync, validation, AI-assisted translation)

They're complementary. A team uses both. Dialect never replaces i18next in React/RN — it feeds it.

This also means an i18next-core competitor (someone who makes i18next JSON the canonical format and extends it to Flutter) is a real risk. The mitigation is speed: ship a working demo and build community before someone else frames the same idea from the JS side.

---

## Relationship with Lokalise / Crowdin

Dialect replaces Lokalise **for teams that don't need a full TMS.** Specifically:

- Teams where developers do translations via AI (no human translator marketplace needed)
- Teams where the "dashboard" is overhead, not value
- Teams where cross-platform sync is the primary pain

Dialect does not replace Lokalise for:

- Orgs with dedicated translation teams
- Compliance-heavy industries needing audit trails
- 50+ locale operations with linguistic QA

The pitch is not "Dialect is better than Lokalise." It's "if you're already using AI to translate, why are you paying for a dashboard and context-switching away from your IDE?"

---

## Where the AI-Native Advantage Actually Lives

"AI-native" is not about having a better AI. It's about giving any AI better context.

| What the AI sees | Dialect (ARB + glossary) | Plain i18next JSON |
|---|---|---|
| String value | Yes | Yes |
| Description of what the string means | Yes (`@description`) | No |
| Context (which screen, which component) | Yes (`@context`) | No |
| Placeholder types | Yes (`@placeholders`) | Inferred from `{{var}}` |
| Glossary (project-specific term translations) | Yes (`glossary.yaml`) | No |
| Tone and formality rules per locale | Yes (`glossary.yaml` style) | No |

This matters for ambiguous words ("Book", "Post", "Match", "Cancel"), tone-sensitive copy, and pluralization. It doesn't matter for simple strings like "Loading..." or "Settings".

The defensibility is: **our convention makes any AI smarter at your project's translations.** Not "our AI is better."

A competitor could add a metadata sidecar to i18next JSON to close this gap. The mitigation is the same as everything else: be first, be adopted, be the standard.

---

## Strategic Risks

| Risk | Probability | Mitigation |
|---|---|---|
| i18next contributor builds "i18next-flutter" with a sync CLI | Low-medium | Ship first. Build community. If it happens, they'll likely contribute to Dialect instead of starting from scratch. |
| Lokalise adds AI-in-editor features | Medium | They're slow to move and dashboard-centric. But they have resources. Ship before they react. |
| ARB format feels too Flutter-centric for non-Flutter devs | Medium | Downplay ARB as "Flutter format" in messaging. Present it as "JSON with metadata" — which is what it is. |
| Solo devs find onboarding intimidating | High | Add a "5-minute quickstart" that isolates the minimum path. Advanced features are opt-in. |
| The convention is easily replicated | High | True. The moat is adoption, not code. Speed and community are the only defense. |

---

## What This Means for the Demo

The 2-minute demo should show:

1. Dev builds a screen in Flutter with hardcoded strings
2. Tells AI to extract and translate
3. AI writes to canonical ARB with descriptions
4. `dialect sync` generates Flutter ARB + iOS `.strings` + Android `strings.xml` + backend flat JSON
5. `dialect check` passes
6. Show all four output files side-by-side — same strings, four different formats, one source

The cross-platform sync moment is the "wow." Not the AI translation. Nobody else syncs ARB, `.strings`, `strings.xml`, and JSON from one canonical source.
