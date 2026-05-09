# Migration & Import Feedback (Package-Owner Lens)

Author: Claude (Stepo-side conversation, 2026-05-20)
Scope: How Dialect should treat adoption from existing-l10n codebases. Concrete v1 changes.

---

## TL;DR

Dialect's adoption story today is "start fresh." That's a niche. The bigger market — and probably the cleaner demo — is teams that already have ARB / .resx / strings.xml / i18next-json and want a unified workflow. Three changes unlock that segment without changing the thesis:

1. **`dialect import` in v1.0** — but as an AI-orchestrator, not a parser.
2. **`.resx` as a Tier-1 adapter** (v1.1, not v1.4) with documented lossy semantics.
3. **Adapter fidelity tiers** in the docs — lossless / faithful / lossy — so trade-offs are honest.

---

## 1. `dialect import` should ship in v1.0 — as an AI-pointer, not a parser

### The gap

The MVP plan has `dialect init` (scaffold-from-scratch) but nothing for "I already have translations." Every real adopter writes a one-off conversion script. That kills the "60 seconds" pitch on day one for anyone who isn't greenfield, which is most of the addressable market.

### The naive design (wrong)

Dialect parses .resx XML / Android strings.xml / i18next-json itself, emits ARB. Pros: works offline, deterministic. Cons: every new source format = adapter + tests; placeholder/plural conversion is fiddly; doesn't compose with the rest of Dialect's AI-first stance.

### The right design

Dialect emits **instructions for an AI agent** and lets the user's existing AI tool do the work. Pattern:

```bash
$ dialect import --from arb --path lib/l10n/
✓ Wrote import plan to .dialect/import-plan.md
  Next: open your AI tool (Claude Code, Cursor, Cline, Copilot, …) and run:
    "Read .dialect/import-plan.md and execute the steps."
$ dialect check
```

The plan file is a structured markdown brief: "read these source files, produce ARBs in dialect/source/ with this key convention, namespaces are X, fill @description from callsite context, plural conversion rule is Y." The agent does the reading, conversion, key renaming, and description backfill. `dialect check` validates the result.

### Why this design is correct for Dialect specifically

- **Philosophically coherent.** `dialect.yaml`'s header comments already teach AIs how to work with the project. `dialect import` is the same pattern: Dialect supplies the spec, the AI executes.
- **Editor-agnostic forever.** Works with Cursor, Claude Code, Cline, Copilot, Windsurf, Aider, anything that reads files. No SDK / API key handling. No vendor lock.
- **Doesn't go stale.** Dialect doesn't call any model, so model upgrades don't force Dialect releases.
- **Single command covers many source formats.** The user (or their AI) figures out what to do from the source files. Dialect just specifies the destination format.
- **Composable with `dialect describe`.** Same pattern: emit an instruction file, the user's agent fills `@description` by reading callsites. AI is materially better at this than at translation (it's reading code, which is its strong suit).

### Optional built-in mode

For CI / scripting, ship `dialect import --auto --provider {anthropic|openai}` as a thin wrapper that calls the LLM directly. But default to the agent-pointer flow and document it as the recommended path. Same call for `dialect translate` — currently planned as built-in in v1.2; reframe so the agent-pointer flow is primary and built-in LLM call is the convenience option.

### Adoption story this unlocks

```
Hour 1: dialect import → AI imports existing ARBs/.resx into dialect/source/
Hour 2: dialect describe → AI fills @descriptions from callsites
Hour 3: AI bulk-renames keys to namespace.camelCase (one prompt)
Hour 4: dialect sync && dialect check, fix warnings
Done in a day.
```

That's a real "AI-native migration" demo — and it's also the 2-minute video clip the MVP plan calls for.

---

## 2. `.resx` should be Tier-1, not v1.4-maybe

The current stance ("v1.4, if teams request it") will silently lose every ASP.NET shop that evaluates Dialect at v1.0–v1.3. They won't ask later — they'll just not be there.

### Why .resx is awkward, but not too awkward

1. **Positional placeholders.** `.resx` uses `{0}, {1}` (string.Format), ARB uses named `{userName}`. Adapter has to invent a stable mapping. Lossy in one direction.
2. **No native ICU plurals.** `.resx` values are flat strings. ARB → .resx with plurals = either drop plural logic or refuse to sync that key. Document the choice.
3. **`@description` round-trips cleanly** via `<comment>`. `placeholders` metadata is lost on reverse import. One-way safe is fine.

Cost to ship: ~1-2 weeks of dev work for someone competent in both formats. ICU stripping is the only real complexity.

### Why this matters more than .gettext

`.resx` is the default ASP.NET pattern. Modern Minimal API tutorials still use it. Install base is huge. Saying "use flat-json instead" tells those teams to abandon `IStringLocalizer<T>` — that's a 200-callsite rewrite as the *first* thing they do with Dialect. That's not adoption-friendly.

`.gettext` is a smaller backend audience and a more self-selected one. Park gettext at v1.4 if you like. Don't park `.resx`.

### Recommended docs framing for ASP.NET

- **Greenfield ASP.NET project:** flat-json + 30-line custom localizer. Preserves Dialect's full feature set. Recommended.
- **Existing ASP.NET project with `IStringLocalizer<T>`:** `.resx` adapter with documented lossy semantics. Adopt without rewriting code.

Let the user pick their poison instead of forcing one path.

---

## 3. Adapter fidelity tiers — fix the implicit "second-class" framing

Right now the docs split adapters into "Core" / "Secondary" / "Later." That's a priority hierarchy, not a capability description, and it reads as "we don't really care about your platform." Replace with explicit fidelity tiers:

| Tier | Meaning | Examples |
|---|---|---|
| **Lossless** | All ARB features preserve round-trip | ARB (Flutter), icu-json |
| **Faithful** | All ARB features convert via a documented mapping (e.g. CLDR plural categories) | `.stringsdict`, Android `<plurals>` |
| **Lossy** | Some ARB features drop on sync; document what's lost | `.resx`, `flat-json`, gettext-po, i18next-json |

Benefits:
- Honest about trade-offs without disparaging any platform.
- Lets users make informed choices ("I need plurals → can't use flat-json").
- Removes the "v1.4, if anyone cares" implication for `.resx` etc. — being lossy is a property, not a priority.
- Future adapter PRs from contributors get a clear template: declare your tier, document the mapping.

---

## 4. Migration mode / soft check (smaller item)

Day-one migrators want warnings, not hard errors. `dialect check --strict` is right for CI; `dialect check` (default) on a freshly-imported project should treat missing descriptions, untranslated keys, and plural-shape mismatches as warnings with helpful "run `dialect describe`" / "run `dialect translate`" hints. Hard mode is for CI; soft mode is for the first 30 days.

Alternatively: auto-detect a fresh import (no `.dialect-state` lock file or similar) and default to soft for the first run. Pick whichever is less surprising.

---

## What I'd file as v1.0 must-haves

If v1.0 is "the convention is real," then:

- [x] `dialect init`, `dialect sync` (Flutter), `dialect check`, `dialect status` — already planned.
- [ ] **`dialect import` (AI-pointer flow)** — single highest-leverage missing feature for adoption.
- [ ] **`dialect describe` (AI-pointer flow)** — multiplies quality of every downstream operation that uses `@description`.
- [ ] **Adapter fidelity tier framing in docs** — pure docs change, ~half day.
- [ ] **Soft-mode `check`** for first run.

For v1.1 (the cross-platform sync release):

- [ ] iOS, Android, flat-json, icu-json adapters — already planned.
- [ ] **`.resx` adapter (lossy, documented)** — promote from v1.4.
- [ ] `dialect import` adapters extended to `.resx`, strings.xml, .strings (still via AI-pointer; the "adapters" are just plan templates).

Defer to later: i18next-json, gettext-po, `dialect translate` built-in, OTA, review UI, hosted services.

---

## The single biggest mindset shift this implies

Dialect's product surface should consistently push work onto the user's AI agent rather than do it itself. Wherever Dialect is tempted to "ship an LLM call" or "ship a parser," ask first: can we ship a structured instruction file instead, and have the user's agent execute it? That's:

- Less code to maintain.
- More agent-agnostic.
- More on-brand ("we are the convention, the AI does the work").
- More resilient to model changes.

`dialect.yaml`'s convention header already does this for *authoring*. `dialect import` / `describe` / `translate` should do it for *operations*.

This is the version of Dialect that's actually defensibly different from i18next + an LLM script. The current docs hint at it but don't fully commit. Commit.

---

# Addendum (2026-05-21): Tactical v1.0 additions after Design Updates 2026-05-20

The 2026-05-20 design update absorbed most of the structural feedback above (import + describe in v1.0, Backend Humility template approach, fidelity axis, soft-mode check, distribution commitments). The strategic shape is now right. Five tactical adds remain that get materially more expensive after launch — none are blockers, all are cheap if scoped now.

## 1. Semantic check heuristics (v1.0)

`dialect check` today validates structural correctness only — keys exist, placeholders match, plural categories valid. That's necessary but doesn't catch the most common AI translation failures. Add cheap heuristic flags that don't require an LLM call:

- Translation identical to source (suggests AI skipped the key).
- Length ratio > 2× or < 0.3× source length (suggests over-expansion or truncation).
- Untranslated English fragments in non-English locale files (regex for common English stopwords).
- Glossary term violations (see #4).
- Suspicious placeholder drift (placeholder present in source but stylized differently in translation).

These are pure-text heuristics — fast, deterministic, no API key. Without them the semantic-correctness ceiling of the AI-pointer flow stays invisible until a user reports a bug in production. Mitigation, not solution — but cheap and high-signal.

## 2. Ship localizer templates as real packages, not docs snippets (v1.0–v1.1)

The Backend Humility framing claims "templates, near-zero maintenance." That's true for Dialect's repo — but "copy this 30-line snippet into your project" puts maintenance on the adopter, and every adopter solves the same problem (JSON load, placeholder substitution, plural resolution, hot reload) slightly differently. Six months in, you have N forks of the same template drifting in N user repos.

Ship them as real packages:

- `Dialect.AspNetCore` (NuGet) — `services.AddDialectLocalization("Resources/locales")`, exposes `IStringLocalizer<T>`.
- `dialect-django` (PyPI) — drop-in `_()` backed by JSON catalogs.
- `@dialect/i18next-fs-backend-preset` (npm) — config wrapper for Node teams.
- `dialect-go` — go-i18n config helper.

Same maintenance burden for Dialect as docs snippets (no format conversion logic, just JSON load + native interface impl), dramatically better adopter ergonomics. Versioned. Documented. Installable via the stack's native package manager. This is the actual product surface for backend adopters — make it a real product surface.

Counter-argument: this expands Dialect's release matrix. Mitigation: keep them in the main repo monorepo-style, release together. The packages are small enough that bundling release engineering is cheap.

## 3. ARB merge driver shipped with `dialect init` (v1.0)

Parallel branches that both touch the same ARB file hit JSON merge conflicts that are easy to resolve wrong — drop a key, mis-merge a plural, conflict-resolve and lose an `@description`. None of this is caught by `dialect check` because the result is still structurally valid.

Ship two things:

1. `dialect init` writes a `.gitattributes` entry: `*.arb merge=dialect`.
2. `dialect merge %O %A %B` subcommand that does key-aware ARB merging: union of keys, conflict markers only on actual value disagreements, preserve metadata ordering.

~Half a day of work. Prevents a class of pain that teams don't see coming until they're 10+ contributors deep. Documented in adoption docs as "set this up on day one."

## 4. Active glossary validation in `dialect check` (v1.0)

`glossary.yaml` today is passive — the AI is *supposed* to honor it during translation. Make it enforceable:

- `dialect check` greps each target locale file for source-language glossary terms.
- For each occurrence, verify the translation contains the prescribed term for that locale.
- Flag mismatches as warnings (or errors with `--strict`).

This makes the glossary load-bearing instead of decorative. Without active validation, glossary entries drift over time as AI translations subtly deviate and no one notices.

Edge cases (case sensitivity, morphological variants, word-boundary detection) are handled per-locale via simple rules in `glossary.yaml`. Don't try to be perfect — be useful.

## 5. Read-only review UI in v1.0, not v1.3

The current MVP plan defers the full review UI to v1.3. That's a 6-month gap during which any team with even one non-dev reviewer (PM, native-speaker validator, copywriter) has no path except "ask the dev to run it." Those teams will bounce in evaluation.

Two paths:

- **Option A (recommended):** Ship a read-only `dialect serve` in v1.0. Table view of source + target side-by-side, glossary highlights, `@description` shown as context. No editing. ~A weekend of Svelte work given the API is already designed. Converts "no UI" from a blocker into "PMs can read context themselves."
- **Option B:** Fully commit to "developer-led workflow, no UI ever" in messaging. Don't ship `serve` at all. The Tailwind-for-l10n positioning would be defensible. But then drop `dialect serve` from the entire roadmap.

The middle ground ("no UI now, full editing UI later") is the worst of both — early adopters hit the gap and don't come back when v1.3 ships. Pick A or B and own it.

## 6. README "Should you use Dialect?" section (v1.0, docs only)

Be explicit, up front, about who Dialect is **not** for:

- Teams with dedicated translation operations (assigned reviewers, approval chains, vendor handoff, audit trails) — Dialect is not the shape of your workflow.
- Regulated industries needing audit trails for every translation change — local-file workflow doesn't fit.
- Locked-down enterprises without AI tools (Cursor, Claude Code, Copilot) — the AI-pointer flow degrades.
- Apps where translation quality is regulatory-critical (medical, legal, financial UX strings) — the semantic-correctness ceiling matters too much.

Front-loading this prevents wrong-fit adopters from self-selecting, writing angry blog posts six months in, and burning your support time. Tailwind, Astro, and Bun all do this well — focused tools say no clearly. Pin a "Should you use Dialect?" section above the install instructions.

---

## Summary table

| # | Item | Scope | Cost | Risk if deferred |
|---|---|---|---|---|
| 1 | Semantic check heuristics | v1.0 | 1-2 days | AI quality failures stay invisible |
| 2 | Real backend packages (NuGet/PyPI/npm) | v1.0–v1.1 | 1 week per stack, release matrix | Template drift across user repos |
| 3 | ARB merge driver in `init` | v1.0 | Half a day | Silent merge data loss at scale |
| 4 | Active glossary validation | v1.0 | 1-2 days | Glossary drifts, becomes decorative |
| 5 | Read-only UI in v1.0 | v1.0 | A weekend | Non-dev reviewers bounce, don't return |
| 6 | "Should you use Dialect?" in README | v1.0 | 1 hour | Wrong adopters self-select, burn support |

None are design rethinks. All are cheaper to scope in than to retrofit. After these, ship.
