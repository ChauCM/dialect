# Dialect init plan

You are the AI agent the developer just asked to *"run dialect init and follow
the instructions."* This file is your playbook. Execute it end-to-end.

Project: **{{PROJECT_NAME}}** ({{PROJECT_TYPE}})
Source locale: `{{SOURCE_LOCALE}}`
Target locales: `{{TARGET_LOCALES}}`
Generated: {{GENERATED_AT}}

This file was written by `dialect init`. The full convention lives in
`dialect/dialect.yaml` — **read it before you start**. If anything below
conflicts with `dialect.yaml`, `dialect.yaml` wins.

The plan is two phases. **Phase 1 (Setup)** is bounded — always finish it
in this chat turn. **Phase 2 (Extract + translate)** depends on codebase
size: for small projects you finish in the same turn; for big ones you
stop after extraction so the developer can sanity-check key names before
the long translation step.

---

## Phase 1 — Setup

### 1.1 — Add Flutter localization dependencies

In `pubspec.yaml`, ensure these are present under `dependencies:`:

```yaml
flutter_localizations:
  sdk: flutter
intl: ^0.19.0
```

Then run `flutter pub get`.

### 1.2 — Configure gen-l10n

Create `l10n.yaml` at the project root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_{{SOURCE_LOCALE}}.arb
output-localization-file: app_localizations.dart
```

### 1.3 — Wire MaterialApp

In your top-level `MaterialApp` (usually `lib/main.dart`), add the imports:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

…and add these properties to `MaterialApp(...)`:

```dart
localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales,
```

### 1.4 — Locale switcher

If the app already has a Language picker (commonly in Settings), wire it
to a `Locale?` state above `MaterialApp` so picking a locale rebuilds the
app with that locale. If no picker exists, add a simple one in the
Settings screen that lists every supported locale by its self-name
(English, Español, 日本語, العربية, Deutsch, Tiếng Việt, …).

### 1.5 — Smoke test the pipeline

`dialect/source/{{SOURCE_LOCALE}}.arb` ships with a `commonExample` seed
entry so we can prove the pipeline works before doing real extraction.

1. Run `dialect sync` so the source ARB lands in `lib/l10n/app_{{SOURCE_LOCALE}}.arb`.
2. Run `flutter pub get` so `flutter gen-l10n` regenerates `AppLocalizations`.
3. Place a temporary `Text(AppLocalizations.of(context)!.commonExample)`
   somewhere visible (e.g. the home screen) just to confirm it renders.

If this fails, stop and report — the loop is broken before Phase 2 even
matters. If it works, you can revert the temporary `Text` widget; Phase 2
will add real strings shortly.

### 1.6 — Report Phase 1 complete

Tell the developer:

- Deps added, `l10n.yaml` created, `MaterialApp` wired, locale switcher in
  place.
- Smoke test passed: one string flows through `AppLocalizations`.
- A rough count of user-facing strings still to extract (grep
  `Text\(\|label:\|SnackBar` under `lib/`).
- Suggested next step: paste **`start translation phase`** in this chat
  to begin Phase 2 — or review the Phase 1 changes first and come back.

---

## Phase 2 — Extract + translate

Triggered by the developer saying `start translation phase` in chat — or
by you continuing automatically if Phase 1 reported ≤ 50 candidate strings.

### Sizing — one threshold

Count candidate user-facing strings under `lib/` (anything inside
`Text(...)`, `label:`, dialog/SnackBar content, etc., excluding things on
the "What NOT to extract" list below).

- **≤ 50 strings** → do extract **and** translate in this chat turn,
  end-to-end. No mid-flight confirmation needed.
- **> 50 strings** → do **extract only** in this turn (steps 2.1 + 2.2),
  then stop and ask the developer to confirm key names look right
  before continuing to translation in a follow-up turn.

You can handle hundreds of keys per turn — the checkpoint isn't a context
gate, it's giving the human a sane place to review key names before you
commit a much longer pile of translation lines downstream of them.

### 2.1 — Extract (always run)

For each user-facing string in the source code that should be localized:

1. Propose a flat **camelCase** key per the convention. Keys are valid
   Dart identifiers (`checkoutBookNow`, `homeYourTrips`, `commonCancel`).
   No dots, no dashes, no leading digit.
2. Add it to `dialect/source/{{SOURCE_LOCALE}}.arb` with full `@key`
   metadata:
   - `namespace` — the logical group (e.g. `checkout`, `home`,
     `settings`, `common`). Required.
   - `description` — what the string means in context.
   - `context` — when the same word can mean different things.
   - `placeholders` — for any ICU `{var}` placeholders.
3. Replace the hardcoded string in the source code with
   `AppLocalizations.of(context)!.<key>`.

**Do NOT extract:**

- Personal names, emails, phone numbers, URLs
- Currency amounts (use placeholders, e.g. `Total: ${amount}`)
- Dates and times (format at runtime with `intl`)
- Language self-names in a picker (these live in a per-locale data table)
- Brand / product names
- Sample or demo content (lorem ipsum, sample listings)

When in doubt: if the string would change for a different user, it's
data — keep it hardcoded.

### 2.2 — Checkpoint (only when > 50 strings)

Stop here. Summarize for the developer:

- Number of keys added, with one example per namespace.
- Any ambiguities you resolved (key naming choices, namespace
  assignments, glossary edge cases).
- Ask: "Look right? Reply `continue translation` to translate all keys
  into {{TARGET_LOCALES}}."

Do not proceed past this point until they confirm.

### 2.3 — Translate

Read `dialect/glossary.yaml` first. For every key in
`dialect/source/{{SOURCE_LOCALE}}.arb`, write a translation in each
locale's file under `dialect/translations/<locale>.arb`. Respect:

- Glossary terms (use the prescribed translation; apply correct
  inflection for verb / noun / gerund forms).
- CLDR plural categories per locale (English/Spanish/German:
  `one/other`; Arabic: `zero/one/two/few/many/other`;
  Japanese/Vietnamese: `other`). Mirror any `=N` exact-match cases the
  source provides.
- Tone and formality per `glossary.yaml`'s `style` block.

Translation files carry only `@@locale` and key/value pairs — **no
`@key` blocks**. The CLI strips them if you add them.

### 2.4 — Normalize, sync, validate

Run, in order, from the project root:

```
dialect check --fix
dialect sync
dialect check
```

Stop and report if any step errors.

### 2.5 — Run the app

```
flutter pub get
flutter run
```

Switch locale via the locale switcher you wired in Phase 1 (or via the
device language settings) and confirm translated text renders.

### 2.6 — Final report

Summarize for the developer:

- Total keys extracted, broken down by namespace.
- Total translations written across {{TARGET_LOCALES}}.
- Any low-confidence translations or ambiguities — name them so the
  developer can review.
- Suggested next step: `dialect serve` to open the dashboard for
  side-by-side review of every translation.

---

## Things you must NOT do (whole-plan guardrails)

- Don't write dotted keys (`checkout.bookNow`). They break
  `flutter gen-l10n`. Use a flat camelCase key + `@key.namespace`.
- Don't translate the source locale itself.
- Don't add `@key` blocks to translation files — the CLI strips them.
- Don't invent new `@key` fields outside the convention.
- Don't delete keys you don't recognize.
- Don't modify source code in ways unrelated to localization
  (replacing hardcoded strings with `AppLocalizations` calls is in scope;
  anything else isn't).
