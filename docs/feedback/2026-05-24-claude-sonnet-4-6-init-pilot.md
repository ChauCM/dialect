# Dialect agent feedback — first run

Agent: Claude (claude-sonnet-4-6), running via Claude Code CLI  
App: `examples/after` — a small Flutter stay-booking demo  
Flow: `dialect init` → Phase 1 (setup) → Phase 2 (extract + translate zh + vi)  
Total keys extracted: 30 across 4 namespaces  
Total translations written: 60 (30 × 2 locales)

---

## What worked well

**The init plan is excellent.** `init-plan.md` reads like a well-scoped engineering spec. The phase split (bounded Phase 1, size-gated Phase 2) is the right instinct — it gives the agent a natural checkpoint rather than one giant wall of instructions.

**`dialect check --fix` is magic.** I wrote the ARB in any order, ran `check --fix`, and got a perfectly normalized file. Knowing I didn't have to care about key sort order while writing freed me to focus on the semantic parts (descriptions, placeholders, plural forms).

**Warning messages are actionable.** Every warning named the file, line, rule, and a concrete hint. The `source_equality` and `length_ratio` warnings both gave me enough context to decide immediately whether to fix or override — I didn't have to look anything up.

**The glossary convention is sound.** Having a canonical term (`Book` = verb, make a reservation) with locale-specific translations prevented me from mechanically substituting "Book" in Chinese where `预订` (noun/verb unified form) is the right answer.

**The `@key.description` discipline pays off.** Because every key had a rich description, I never had to re-read the source code to translate `checkoutBookNow` — I could work purely from the ARB.

---

## Friction points (with concrete suggestions)

### 1. `flutter: generate: true` is missing from the plan — hard blocker

**What happened:** `flutter gen-l10n` exited with:
```
Attempted to generate localizations code without having the flutter: generate flag turned on.
```
The plan covers adding `flutter_localizations` and `intl: any` to `pubspec.yaml` but never mentions `flutter: generate: true` under the `flutter:` section.

**Impact:** Any agent (or human) following the plan verbatim will hit this error. It's not subtle — nothing works until you add the flag.

**Suggestion:** Add step 1.1b to the plan:
```
In pubspec.yaml, also add `generate: true` under the `flutter:` section:

  flutter:
    generate: true   ← required for flutter gen-l10n to run
    uses-material-design: true
```
Alternatively, `dialect init` could write `generate: true` directly into `pubspec.yaml` if it detects a Flutter project (it already reads pubspec.yaml to detect `Detected project type: Flutter`).

---

### 2. `namespaces: [common]` default silently truncates sync output

**What happened:** I extracted 30 keys across `common`, `home`, `checkout`, and `settings`, ran `dialect sync`, and the output `lib/l10n/app_en.arb` contained only 2 keys — `commonCancel` and `commonLoading`. `flutter gen-l10n` then generated an `AppLocalizations` class with only those 2 methods. I wired up all 30 call sites, ran `dart analyze`, and got 29 undefined-getter errors.

The root cause: `dialect.yaml` ships with `namespaces: [common]` and the plan never mentions updating it as new namespaces are assigned.

**Impact:** This is a silent failure — `dialect sync` exits 0 and says "wrote 1 file" without any indication that 28 keys were dropped. An agent (or developer) who doesn't know to check this will be confused by the analyzer errors.

**Suggestions (pick one or combine):**

a. **Plan step**: Add an explicit instruction in Phase 2.1 — "After assigning namespaces to your extracted keys, update `dialect.yaml`'s `platforms.flutter.namespaces` list to include every namespace you used."

b. **CLI warning**: When `dialect sync` drops keys because their namespace isn't listed, emit a warning:
```
⚠ 28 keys skipped (namespaces not in platforms.flutter.namespaces): checkout, home, settings
  hint: Add these namespaces to dialect.yaml → platforms.flutter.namespaces to include them.
```

c. **Auto-expand**: `dialect init` could set `namespaces: '*'` (all) as the default, with a comment explaining how to restrict it. Opting into restriction is less surprising than silently dropping keys.

Option (b) alone would have let me self-correct in seconds rather than tracing analyzer errors back to the config.

---

### 3. `flutter gen-l10n` must be re-run after every `dialect sync` — not stated in the plan

**What happened:** The plan's Phase 2.4 sequence is `dialect check --fix → dialect sync → dialect check`. Phase 2.5 is `flutter pub get && flutter run`. Neither step mentions running `flutter gen-l10n` between sync and run.

In practice the sequence is:
1. `dialect sync` → writes `lib/l10n/app_en.arb` (and locale ARBs)
2. `flutter gen-l10n` → regenerates `app_localizations.dart` and per-locale files
3. `flutter run` → compiles against the regenerated class

If you skip step 2, you run against a stale `AppLocalizations` and get runtime errors or silent fallback behavior.

**Suggestion:** Update Phase 2.4 to:
```
dialect check --fix
dialect sync
flutter gen-l10n    ← regenerates AppLocalizations from the synced ARBs
dialect check
```

---

### 4. Chinese length_ratio — the default threshold doesn't fit CJK

**What happened:** Chinese translations for strings like "Notifications" → "通知", "Language" → "语言", and "Settings" → "设置" all tripped the default `[0.3, 2.5]` ratio. These are correct translations — Chinese characters carry far more meaning per glyph than English letters.

I added `zh: [0.1, 2.0]` to `dialect.yaml` manually, but only because I understood what the warning meant.

**Suggestion:** Pre-configure reasonable CJK overrides in `dialect.yaml` whenever `zh`, `ja`, or `ko` appear in `target_locales`. Either:

a. Ship them as commented-out examples in the `length_ratio:` block:
```yaml
length_ratio:
  # CJK languages pack more meaning per character — lower bound needed:
  # zh: [0.1, 2.0]
  # ja: [0.1, 2.0]
  # ko: [0.1, 2.0]
```

b. Or have `dialect init` (or `dialect check --fix`) auto-add the override the first time it fires for a CJK locale.

---

### 5. The locale switcher pattern is underspecified in the plan

**What happened:** Phase 1.4 says "wire it to a `Locale?` state above `MaterialApp`." For the agent, this meant:
- Changing `ExampleApp` from `StatelessWidget` to `StatefulWidget`
- Adding a `Locale? _locale` field and a `_setLocale` callback
- Threading `onLocaleChanged` as a constructor parameter through `HomeScreen` → `SettingsScreen`

This is correct but non-trivial, especially in larger apps where the Settings screen is several navigational hops from `MaterialApp`. An agent working on a real app may thread it wrong (passing through too many layers) or reach for a state-management package.

**Suggestion:** The plan could note that the idiomatic Flutter approach for a simple app is prop drilling via callbacks, but for deeper trees, `InheritedWidget` or a lightweight state package (`provider`, `riverpod`) is the standard answer — and that Dialect has no opinion on which you use.

---

### 6. `commonExample` seed key is orphaned after Phase 2

**What happened:** `dialect/source/en.arb` ships with a `commonExample` seed key. The plan says "Delete this once you've added your first real string" (in the ARB comment), but the init plan itself never explicitly instructs the agent to remove it. I left it in the source ARB (it doesn't cause errors) but it would appear in `AppLocalizations` as a dead method.

**Suggestion:** Add one line to Phase 2.1: "Remove the `commonExample` seed key and its `@commonExample` block from `dialect/source/en.arb` once you've added your first real key."

---

### 7. `dialect.yaml` project description is still placeholder text

After init, `dialect.yaml` reads:
```yaml
project:
  name: "Your project"
  description: >
    One-line description of what your app does...
```

The plan never prompts the agent to fill this in. These fields matter — the convention doc says "Translators and AI assistants read this to disambiguate glossary terms." If the project description is placeholder text, future agents get no disambiguation context.

**Suggestion:** Add a step to Phase 1 (or Phase 2.1): "Update `dialect.yaml → project.name` and `project.description` with the actual app name and a one-line description. Example for this app: `name: 'Stay Booking Demo'`, `description: 'A travel stay booking app where users browse listings, check out, and manage trips.'`"

---

### 8. `source_equality` warning can't be dismissed in-ARB — requires the dashboard

The `vi settingsEmail = "Email"` warning is correct behavior, but the only way to silence it is via `dialect serve` (locking the entry). If a developer isn't running the dashboard, this warning will persist in every `dialect check` run.

**Suggestion:** Support an in-ARB escape hatch in the source key's `@key` block:
```json
"@settingsEmail": {
  "namespace": "settings",
  "description": "...",
  "source_equality_exempt": ["vi", "id", "ms"]
}
```
This follows the existing `glossary_exempt` pattern and doesn't require the dashboard to be running.

---

## Minor observations

- `dialect init` detecting Flutter from `pubspec.yaml` is smart. It correctly chose `arb` format and `lib/l10n/` output without prompting.
- The convention doc inside `dialect.yaml` is thorough enough that I didn't need to re-read the external docs during translation. That's a high bar to hit — keep it.
- The "What NOT to extract" list in the plan is exactly right. "Seaside cottage in Da Nang" and "Linh" are sample data, not copy, and the list made that call easy.
- Vietnamese plural is single-form (CLDR `other` only), same as Chinese. The plan's CLDR reference table covers this correctly.
- The `dialect check` run after `sync` is a good sanity gate. Catching a malformed placeholder or missing CLDR category before `flutter run` saves a confusing runtime crash.

---

## Priority ranking

| # | Issue | Severity | Effort |
|---|-------|----------|--------|
| 1 | Missing `generate: true` in plan (or auto-write in CLI) | **Blocker** | Low |
| 2 | Namespace truncation is silent | **High** | Medium |
| 3 | `flutter gen-l10n` missing from Phase 2.4 sequence | **High** | Low |
| 4 | CJK length_ratio defaults | Medium | Low |
| 5 | Locale switcher pattern underspecified | Medium | Low |
| 6 | `commonExample` removal not instructed | Low | Low |
| 7 | Project description stays placeholder | Low | Low |
| 8 | `source_equality_exempt` in-ARB escape hatch | Low | Medium |
