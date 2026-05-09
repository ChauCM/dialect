# The Post-Dashboard Era of Localization

## The Simple Thesis

Localization is broken — but not in a way that needs a complex new system to fix.

The real insight is this: **developers who code with AI already have the perfect translator sitting right next to them.** When you just built a checkout screen in Flutter, your AI co-pilot has full context — the widget tree, the button semantics, the user flow. You can just say *"add the labels on this screen to translations and translate them into Spanish, Japanese, and Arabic"* and it should just work.

No daemon. No file watcher. No AST parser. No new infrastructure to learn. The AI already understands the code. The missing piece isn't intelligence — it's **a good standard for how translation files should be organized** and **a simple tool to keep platforms in sync**.

---

## Why the Current Way Sucks

You're a Flutter dev. You know this pain:

1. You build a new screen with 15 labels.
2. You open `app_en.arb`, manually add 15 keys, think of sensible key names.
3. You open `app_es.arb`, `app_ja.arb`, `app_ar.arb`... copy the structure, Google Translate (or worse, leave them blank for later).
4. You wire up `AppLocalizations.of(context).someKey` in your widgets.
5. A PM opens Crowdin, sees the new keys, assigns them to translators who have no idea what screen these strings are on.
6. Translators translate "Book" as a noun. It was a verb. QA catches it two weeks later.
7. Someone adds a string on the backend. Now the mobile app and the API have different translation files that slowly drift apart.

The dashboard tools (Crowdin, Lokalise, Phrase) were built for a world where translation was a human coordination problem. They made sense when you needed 50 translators working on spreadsheets. But now LLMs translate better than most freelancers for UI strings, and developers already talk to AI all day.

**The dashboard is the bottleneck, not the solution.**

---

## The Real Observation

If you're coding with Cursor, Copilot, or any AI assistant:

- You say: *"Create a booking confirmation screen"*
- The AI writes the whole screen with hardcoded strings.
- You say: *"Now extract all strings to ARB files and translate to Spanish and Japanese"*
- The AI... can actually do this right now. It has the full context. It knows "Book" is a verb because it just wrote the `onPressed: _handleBooking` callback.

**The AI-as-translator already works.** What's missing is:

1. A clean standard for how the translation files should look, so the AI produces consistent output every time.
2. A way to keep those files in sync when you have multiple platforms (Flutter + web + backend) sharing the same strings.
3. A simple validation step to catch mistakes.

That's it. That's the whole product.

---

## What We Actually Need to Build

### 1. A Translation File Standard (the "Spec")

A simple, opinionated convention for organizing translation files that any AI can follow. Not a new format — just a clear structure using `.arb` and `.json` files that already exist.

```
project-root/
├── l10n/
│   ├── l10n.yaml              # Config: locales, platforms, glossary
│   ├── source/
│   │   └── en.arb             # Source strings (Flutter ARB as canonical format)
│   ├── translations/
│   │   ├── es.arb
│   │   ├── ja.arb
│   │   ├── ar.arb
│   │   └── ...
│   └── glossary.yaml          # Project-specific terms the AI should respect
```

Why ARB as the canonical format? Because it already supports metadata, placeholders, and pluralization via ICU MessageFormat. It's what Flutter uses natively. And it's just JSON under the hood — trivial for any AI to read and write.

```json
{
  "@@locale": "en",
  "checkoutBookNow": "Book Now",
  "@checkoutBookNow": {
    "description": "CTA button on checkout screen, verb meaning 'make a reservation'",
    "context": "checkout_screen"
  },
  "checkoutItemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "@checkoutItemCount": {
    "description": "Item count display on checkout screen",
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

The `@key` metadata entries are where context lives. When an AI extracts strings, it fills these in automatically because it just wrote the code. When another AI (or the same one later) translates, it reads them. Simple.

### 2. A Sync CLI (the "Glue")

A lightweight CLI tool that solves the multi-platform problem:

```bash
# Initialize in your project
l10n init --source-format arb --platforms flutter,react,backend

# Sync: read canonical ARB files, generate platform-specific outputs
l10n sync

# Check: find missing translations, broken placeholders
l10n check

# Status: quick overview
l10n status
```

What `l10n sync` actually does:

```
l10n/source/en.arb (canonical)
       │
       ├──▶ lib/l10n/app_en.arb          (Flutter — just copies)
       ├──▶ web/public/locales/en.json    (React i18next format)
       └──▶ api/locales/en.json           (Backend flat JSON)

l10n/translations/es.arb (canonical)
       │
       ├──▶ lib/l10n/app_es.arb
       ├──▶ web/public/locales/es.json
       └──▶ api/locales/es.json
```

That's it. The CLI is a format converter + file copier. It doesn't translate anything. It doesn't parse your code. It doesn't talk to any API. It just keeps platform-specific files in sync from one canonical source.

You could write this in Dart (so Flutter devs can contribute easily) or in Go/Rust for speed. Honestly, for the number of files involved, even a shell script would work. **The value is in the convention, not the implementation.**

### 3. A Validation Layer (the "Safety Net")

Things the CLI checks:

- Every key in `en.arb` exists in all target locale `.arb` files.
- Placeholder variables match across translations (`{count}` in English must appear in Spanish too).
- ICU plural categories are valid for each locale (Arabic needs `zero`, `one`, `two`, `few`, `many`, `other`).
- No obviously broken strings (empty values, untranslated English left in other locale files).

```bash
$ l10n check
  ✓ 247 keys across 6 locales
  ✗ ar.arb: missing plural category 'two' for key 'checkoutItemCount'
  ✗ ja.arb: missing key 'settingsNotifications'  
  ⚠ es.arb: 'checkoutBookNow' still contains English text
```

This runs in CI. PR doesn't merge if translations are broken.

---

## The Developer Workflow (How It Actually Feels)

### Day-to-Day: Just Talk to Your AI

```
You:  "I just built the settings screen. Extract all the hardcoded 
       strings, add them to l10n/source/en.arb with good keys and 
       descriptions, then translate to Spanish and Japanese."

AI:   *reads your settings_screen.dart*
      *adds 12 keys to en.arb with contextual descriptions*
      *creates/updates es.arb and ja.arb with translations*
      *rewrites your widgets to use AppLocalizations*

You:  "Run l10n sync and l10n check"

AI:   *syncs to all platform outputs*
      *all checks pass*

You:  *commits and pushes*
```

Total time spent on localization: **30 seconds of typing a prompt.**

### Adding a New Locale

```
You:  "We're launching in Germany. Add German translations for 
       all existing strings."

AI:   *reads en.arb (with all the contextual descriptions)*
      *creates de.arb with translations*
      *reads glossary.yaml for project-specific terms*

You:  "l10n sync"
      Done.
```

### Onboarding a New Platform

```
You:  "We're building a React web app that shares strings with 
       our Flutter app. Add a react platform adapter."

You:  *edits l10n.yaml to add react platform config*
      "l10n sync"
      *React i18next JSON files appear*
```

---

## The Config File

```yaml
# l10n/l10n.yaml

source_locale: en
target_locales: [es, ja, ar, de, fr, zh]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
  
  react:
    output: web/public/locales/
    format: i18next-json
    # i18next uses nested keys: checkout.bookNow instead of checkoutBookNow
    key_style: nested_dot
  
  backend:
    output: api/locales/
    format: flat-json
```

## The Glossary

A simple YAML file that gives the AI (and future human reviewers) consistent terminology:

```yaml
# l10n/glossary.yaml

terms:
  - term: "Book"
    meaning: "To make a reservation (verb), NOT a physical book"
    translations:
      es: "Reservar"
      ja: "予約する"
      ar: "احجز"

  - term: "Host"
    meaning: "A person who lists their property, NOT a computer server"
    translations:
      es: "Anfitrión"
      ja: "ホスト"

  - term: "Experience"
    meaning: "A bookable activity/tour, our product term"
    translations:
      es: "Experiencia"
      ja: "体験"

style:
  tone: "friendly, concise"
  formality:
    es: "tú (informal)"
    de: "Sie (formal)"
    ja: "です/ます (polite)"
```

When a developer tells their AI *"translate these strings"*, the AI reads this glossary and gets it right the first time. No QA loops.

---

## The Multi-Platform Sync Problem (The Actually Hard Part)

The interesting engineering challenge isn't translation — it's keeping a Flutter app, a React web app, and a backend API all speaking the same language (literally).

### The Problem

Each platform has its own format and conventions:

| Platform | Format | Key Style | Pluralization |
|---|---|---|---|
| Flutter | `.arb` | `camelCase` | ICU MessageFormat |
| React (i18next) | `.json` | `nested.dot.keys` | i18next plural syntax |
| iOS | `.strings` / `.stringsdict` | `snake_case` | Apple plist format |
| Android | `.xml` | `snake_case` | Android plural syntax |
| Backend | `.json` / `.yaml` | varies | varies |

Same string, five different representations. The sync tool needs to convert between these losslessly.

### The Solution: Canonical ARB + Platform Adapters

ARB is the richest format (it carries metadata and supports ICU MessageFormat natively). Use it as the canonical source and convert down to simpler formats:

```
ARB (canonical, full metadata)
 │
 ├── Flutter:  direct copy (ARB is native)
 ├── i18next:  convert keys to dot notation, plurals to i18next format
 ├── iOS:      convert to .strings + .stringsdict
 ├── Android:  convert to strings.xml + plurals.xml
 └── Backend:  flatten to simple key-value JSON
```

Each adapter is ~100-200 lines of code. They're boring format converters. But getting them right (especially pluralization edge cases) is where the real value lives.

### What About Shared vs. Platform-Specific Strings?

Not every string is shared. The mobile app has "Pull to refresh" — the web doesn't. The backend has error messages the frontend never shows.

Simple solution: **namespaces in the key names.**

```json
{
  "@@locale": "en",
  "common.loading": "Loading...",
  "@common.loading": { "description": "Shared across all platforms" },
  
  "mobile.pullToRefresh": "Pull to refresh",
  "@mobile.pullToRefresh": { "description": "Mobile only" },
  
  "web.cookieConsent": "We use cookies to improve your experience",
  "@web.cookieConsent": { "description": "Web only" }
}
```

The sync tool only copies relevant namespaces to each platform. Configure it in `l10n.yaml`:

```yaml
platforms:
  flutter:
    namespaces: [common, mobile]
  react:
    namespaces: [common, web]
  backend:
    namespaces: [common, backend]
```

---

## Why Open Source Makes Sense Here

This is a **convention + a small CLI tool**, not a SaaS platform. The value proposition is:

1. **The spec is the product.** If enough teams adopt the same file structure and conventions, every AI tool (Cursor, Copilot, Windsurf, whatever comes next) will learn to produce consistent output. Network effects come from adoption, not lock-in.

2. **The CLI is simple.** Format conversion and validation are well-defined problems. The community can add platform adapters (someone will want Svelte, someone will want Go templates, etc.).

3. **The AI does the hard work.** Translation quality comes from the LLM, not from the tool. The tool just enforces structure. As LLMs get better, the translations get better — for free.

### Could You Make Money?

Maybe, but probably not from the core tool. Possible angles:

- **Hosted CI integration**: A GitHub Action / service that runs `l10n check` and posts PR comments with translation diffs. Free tier + paid for large teams.
- **Translation review marketplace**: Connect teams with human reviewers for high-stakes strings (legal, marketing). Take a cut.
- **Enterprise support**: Guaranteed SLAs, custom adapters, on-prem LLM integration.
- **Quality scoring API**: Rate translation quality, detect drift, suggest improvements. Freemium.

But honestly? If this becomes a widely-adopted open-source standard, that's a better outcome than a mediocre SaaS. The Flutter community especially is hungry for this — the current `flutter_localizations` + `intl` + `arb` workflow is tedious, and there's no dominant AI-native tool yet.

---

## MVP: What to Build First

**Week 1-2: The Spec**
- Write the file structure convention as a clear README.
- Define the ARB-as-canonical-source pattern.
- Write example `l10n.yaml` and `glossary.yaml`.
- Create a sample project (Flutter app) with the structure in place.

**Week 3-4: The CLI (`l10n`)**
- `l10n init` — scaffold the `l10n/` directory.
- `l10n sync` — convert canonical ARB to platform-specific formats.
- `l10n check` — validate completeness and correctness.
- `l10n status` — show coverage table.
- Start with two adapters: Flutter (ARB, trivial) and React (i18next JSON).

**Week 5-6: The AI Prompt Templates**
- Write well-crafted prompt templates / Cursor rules / custom instructions that teach AI assistants to:
  - Extract strings from code into the canonical ARB format.
  - Read the glossary and respect project-specific terms.
  - Translate with context from `@key` metadata.
  - Follow the exact file structure convention.
- Publish these as a `.cursorrules` file, a Copilot custom instruction, etc.

**Week 7-8: Polish and Launch**
- GitHub Action for `l10n check` in CI.
- Good docs, good examples.
- Post on Flutter Reddit, dev.to, Hacker News.
- Let the community tell you what adapter they want next.

---

## Evaluation: Is Your Simpler Direction Better?

### The Honest Answer: Yes, But They're Complementary

Your direction (simple spec + tiny CLI + let the AI do the work) is **better as a starting point**. My original direction (three-tier system with AST parsers and daemons) was solving problems you don't have yet and might never have.

Here's why your instinct is right:

**You correctly identified that the AI context problem is already solved.** The whole "concentric context rings" and "AST-based context extraction" architecture I proposed was building an elaborate system to give the LLM context it already has. When you're in Cursor and you just wrote the screen, the AI has the full file, the imports, the widget tree — everything. Building custom parsing infrastructure to recreate that context is solving a solved problem.

**You correctly identified the real gap.** The actual pain is not "how does the AI understand my code" — it's "how do I keep 6 locale files and 3 platform formats consistent." That's a format conversion and validation problem, not an AI problem.

**You correctly scoped the MVP.** A spec + CLI + Cursor rules is something one person can ship. A three-tier LSP + daemon + CI system is a 6-month project for a team.

### Where My Original Direction Still Has Merit

The feedback you received identifies the real blind spots, and some of them naturally pull you back toward pieces of my original architecture — but only pieces, adopted incrementally:

**1. The Token Limit Problem is Real**

When your app grows to 2,000+ strings, telling Cursor "read en.arb and add German" will break. The AI will hallucinate keys, drop existing ones, or hit context limits. This is where `l10n translate` (the CLI calling an LLM API directly for just the diff) becomes necessary. That's essentially a stripped-down version of my "Tier 2 CLI" — but only the translation part, only when needed.

**2. The Split-File Architecture is Smart**

The suggestion to split into `features/checkout_en.arb` and `features/settings_en.arb` is good and solves merge conflicts. But it also means `l10n sync` needs to be smarter — it's concatenating, resolving namespace collisions, and maintaining key uniqueness across files. Still simple, but no longer "just a file copier."

**3. The `l10n serve` Idea is Interesting But Dangerous**

A local web UI for PMs to review translations sounds helpful. But the moment you build a web UI, you're on the road to rebuilding the dashboard you're trying to kill. Be very careful here. A better v1 is: `l10n diff --format markdown` that outputs a clean table PMs can read in a GitHub PR comment. Keep them in the PR review flow, not in a separate tool.

### What's Actually New vs. What Already Exists

Let's be brutally honest about what exists today:

| Tool | What it does | What it doesn't do |
|---|---|---|
| `flutter gen-l10n` | Generates Dart code from ARB files | No multi-platform sync, no validation beyond Flutter |
| `i18n-ally` (VS Code) | Shows inline translations, basic extraction | No AI translation, no cross-platform sync |
| `Replexica` | AI-powered translation CLI | Tied to their cloud, not spec-first, not open |
| `Languine` | AI translation for multiple formats | SaaS-first, not a convention/standard |
| `Paraglide (Inlang)` | Compiler-based i18n | Complex setup, own message format, no AI |

**Nobody has built the "canonical ARB + platform adapter + AI-convention" combo.** That's the gap. The individual pieces exist (ARB exists, format converters exist, AI translation exists) but nobody has packaged them into a single coherent workflow with a spec that AI tools can standardize around.

---

## Is This a Viable Business?

### Short Answer: It's a Viable *Project*. It's a Hard *Business*.

Let me separate these clearly.

### As an Open Source Project: Strong Viability

- The Flutter community is underserved. The current `flutter_localizations` workflow is universally hated.
- The "AI-native localization convention" angle is genuinely novel and timely.
- It's small enough for one person to build and maintain.
- If it gets traction, it becomes a portfolio piece / reputation builder that's worth more than most side-project revenue.

### As a Business: Challenging, But Possible

**The hard truth:** You're building a format converter and a spec. These are commodities. The PLG playbook (free CLI → paid enterprise dashboard) that the feedback describes is correct in theory but extremely hard in practice:

- **Vercel** had Next.js (millions of users) before they could sell hosting.
- **Tailwind** had massive adoption before Tailwind UI made money.
- **Supabase** had Firebase's failures to exploit.

You need thousands of teams using your spec before enterprise features become sellable. That's a multi-year adoption curve.

**Realistic revenue paths, ranked by feasibility for a solo dev:**

| Path | Effort | Revenue Potential | Timeline |
|---|---|---|---|
| Consulting / freelance ("I'll set up AI localization for your Flutter app") | Low | $5-15K/project | Immediate |
| Cursor rules / prompt packs (sell on Gumroad) | Low | $1-5K total | 1-2 months |
| Premium adapters (iOS .stringsdict, Android plurals — the annoying edge cases) | Medium | $10-30/mo per team | 3-6 months |
| GitHub Action (hosted `l10n check` with LLM quality scoring) | Medium | $20-50/mo per team | 6 months |
| "Vercel for Localization" dashboard | High | Potentially large | 12+ months, needs traction first |

**My honest recommendation:** Build it as open source, get known for it, and monetize through consulting and premium add-ons. Don't plan for the SaaS dashboard until you have clear demand.

---

## Solo Dev Effort Estimate

### What's Actually Easy (1-2 weeks each)

- **The spec and docs.** Write the convention, the README, the example project. This is writing, not coding.
- **`l10n init`.** Scaffold a directory. Trivial.
- **`l10n check`.** Parse ARB files, compare keys across locales, validate placeholders. Straightforward JSON diffing.
- **`l10n status`.** Read files, count keys, print a table.
- **Flutter adapter.** ARB-to-ARB is literally a file copy. Done.
- **Cursor rules.** Write `.cursorrules` that teach the AI the convention. This is prompt engineering, not code.

### What's Moderately Hard (2-4 weeks each)

- **`l10n sync` with the i18next adapter.** Key style conversion (camelCase → nested.dot), plural format conversion (ICU → i18next). Lots of edge cases.
- **`l10n translate` (the LLM-powered diff-and-translate command).** Needs to diff ARB files, batch missing keys, call an LLM API, parse the response, and write back valid ARB. Error handling and retry logic takes time.
- **Split-file architecture.** Supporting `features/*.arb` → merged canonical output adds real complexity to the sync pipeline.

### What's Hard (4-8 weeks)

- **iOS adapter (.strings + .stringsdict).** Apple's pluralization format is XML-based and deeply weird. Getting it right for all plural categories across all locales is a rabbit hole.
- **Android adapter (strings.xml + plurals.xml).** Similar XML weirdness, plus resource qualifiers.
- **Robust ICU MessageFormat parsing.** Nested plurals, select expressions, gender variants — the full ICU spec is complex.

### Realistic Timeline for One Person

| Milestone | Scope | Time |
|---|---|---|
| **v0.1 — Proof of concept** | Spec + `l10n init` + `l10n check` + `l10n status` + Flutter adapter + Cursor rules | 3-4 weeks |
| **v0.2 — Multi-platform** | `l10n sync` with i18next adapter + split-file support | 3-4 weeks |
| **v0.3 — AI translation** | `l10n translate` with OpenAI/Anthropic API | 2-3 weeks |
| **v0.4 — CI integration** | GitHub Action + `l10n diff` for PR comments | 1-2 weeks |
| **v1.0 — Production ready** | iOS + Android adapters, robust ICU parsing, good error messages, full docs | 4-6 weeks |

**Total to v1.0: ~4-5 months of focused weekend/evening work, or ~2 months full-time.**

That's very doable for a solo dev. The key is to ship v0.1 fast (Flutter-only, no translation command, just the spec + check + Cursor rules) and get feedback from real Flutter devs before building the harder parts.

---

## The Answer to "What Should I Build This Weekend?"

**Start with the Cursor rules + spec + a real Flutter project, not the CLI.**

Here's why: the CLI is the boring part. The magic moment is when you open Cursor in a Flutter project, type "extract all strings on this screen to translations and translate to Spanish", and the AI does it perfectly because your `.cursorrules` file teaches it the exact convention.

If you can record a 2-minute demo of that workflow and post it to Flutter Reddit / Twitter, you'll know within 48 hours if people care. If they do, then build the CLI. If they don't, you saved yourself months.

Concrete steps for this weekend:

1. Create a sample Flutter app with 2-3 screens and hardcoded strings.
2. Create the `l10n/` directory structure with the spec.
3. Write a `.cursorrules` file that teaches Cursor the convention.
4. Test it: can Cursor reliably extract, key, and translate strings?
5. Record the demo.

The CLI can wait. The convention can't.

---

## The Bet

The bet is simple: **the best localization tool is no tool at all — just a good convention that AI already knows how to follow.**

We don't need to build a smarter system. We need to build a thinner one. A standard that's so simple and obvious that every AI assistant produces correct translation files on the first try, and a tiny CLI that keeps those files in sync across platforms.

The developer never opens a dashboard. The developer never writes a sync script. The developer just says *"translate this"* and it's done.

That's the post-dashboard era.
