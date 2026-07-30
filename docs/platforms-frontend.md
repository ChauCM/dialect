# Frontend Platforms

How Dialect integrates with frontend frameworks. **Flutter is the first-class frontend target; a web front end alongside it is supported through the `icu-json` contract.**

> **Scope notice (2026-05, revised 2026-07).** Native iOS `.strings`/`.stringsdict` and native Android `strings.xml`/`<plurals>` adapters are **not on the roadmap**. Flutter generates iOS/Android-compatible output from `AppLocalizations` via its own build pipeline; standalone native string files only matter for edge cases (method channels, native plugins, launch screens). The sections below remain for reference — they describe the conversion patterns if you need to hand-write native files for those cases — but Dialect does not generate them automatically. See [`roadmap.md`](roadmap.md).
>
> **Web is a different case, and the 2026-05 text got it wrong.** "React web is secondary, `i18next` covers it" is the right answer for a *web-only* team choosing a localization tool. It is the wrong answer for a Flutter-led team whose marketing site or share pages are the third consumer of the same strings — which is the exact shape Dialect exists for. That team does not need a per-framework adapter; it needs the `icu-json` contract and about forty lines of runtime. See [JavaScript / TypeScript web](#javascript--typescript-web) below.

---

## Flutter

**Priority: Primary.** Flutter is the home audience. ARB is the canonical format, so the adapter is trivial.

### Format

Dialect's canonical source is ARB — the best universal source format (JSON-based, metadata-rich, ICU MessageFormat built in, identifier-safe keys). Flutter happens to use ARB natively, which is why the Flutter adapter is trivial — `dialect sync` filters by `@key.namespace` and writes the result to the Flutter output directory with no format conversion.

```
dialect/source/en.arb → lib/l10n/app_en.arb
dialect/translations/es.arb → lib/l10n/app_es.arb
```

### `flutter gen-l10n` compatibility

Dialect's keys are flat camelCase Dart identifiers (`checkoutBookNow`) by design — exactly what `flutter gen-l10n` expects. Run `flutter pub get` after `dialect sync` and `gen-l10n` regenerates `AppLocalizations` automatically. Callsites read `AppLocalizations.of(context)!.checkoutBookNow`. No mangling, no name-clash workarounds.

If a project already has a `lib/l10n/` populated by a prior `gen-l10n` setup, run `dialect import --from arb --path lib/l10n/` instead of `init` — it generates an import plan that maps existing keys into the Dialect convention without clobbering work.

### Rich text inside one sentence

A sentence with a styled run in the middle ("When your account is private, **new followers must send a request you approve**. …") is still ONE sentence, and it stays one key. Splitting it into lead/bold/tail keys is a translation defect factory: a translator cannot translate a fragment they never see in context, and many languages will not break the sentence where English does.

The recipe:

- Author the styled run as an inline HTML-style tag in the ARB value:

  ```json
  "settingsPrivateAccountNote": "When your account is private, <b>new followers must send a request you approve</b>. …"
  ```

- **Tags, not braces.** `{b}…{/b}` fights the ARB parser — braces are ICU placeholder syntax and `{/b}` is not a legal placeholder name. `<b>` passes through `gen_l10n` as literal text, and every translator on earth has seen it.
- Keep the tag set closed and small (`<b>` for emphasis; add a second tag only when a real sentence needs a second run style). Placeholders may sit inside tags (`<b>stepping with {name}</b>`); user-generated content is always a placeholder, never markup.
- One small app-side helper parses the tag runs and rebuilds `TextSpan`s from a tag → `TextStyle` map supplied at the call site, so styles stay in the widget code where they belong. Tap targets ride the same map (a tag → `GestureRecognizer` map alongside the styles).
- Translations move the tags to the target language's word order — the tag wraps the *meaning*, not the English position.

`dialect check` enforces the contract with the `tag_balance` rule: tags in every value must balance (properly nested), and a translation must carry exactly its source key's tag set — same tags, same counts. A dropped `</b>` bolds the rest of the sentence; an invented tag renders literally in the UI; both are errors, not warnings.

### OTA

Full support via the `dialect_ota` package. A custom `LocalizationsDelegate` fetches translations from any HTTP endpoint, caches locally, and falls back to bundled translations when offline. See [OTA documentation](ota.md).

```dart
DialectLocalizationsDelegate(
  baseUrl: 'https://myapp.com/translations',
  fallback: AppLocalizations.delegate,
  checkInterval: Duration(hours: 1),
)
```

### Config

```yaml
platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common, mobile]
```

### AI Workflow

```
You:  "Extract all strings from checkout_screen.dart into
       dialect/source/en.arb and translate to Spanish."

AI:   *reads checkout_screen.dart*
      *adds keys with @key.namespace + @description to en.arb (e.g. checkoutBookNow)*
      *translates to es.arb*
      *rewrites widget to use AppLocalizations.of(context)!.checkoutBookNow*
```

---

## iOS (Swift) — out of v1 scope

**Priority: Reference only.** Dialect does **not** ship an `apple-strings` adapter. The sections below describe the conversion pattern for teams who need to hand-write `.strings` / `.stringsdict` for native edge cases (method channel callbacks, launch screens, native plugins).

For Flutter apps, the iOS build produces an `.ipa` containing `AppLocalizations` and the bundled ARBs; you don't need separate native string files for the Flutter UI layer.

Translations ship with the app binary. OTA is not supported for iOS native (Apple's `NSLocalizedString` reads from the compiled bundle).

### Format

Apple uses two files for localization:

- **`.strings`** — flat key-value pairs for simple strings
- **`.stringsdict`** — XML plist for pluralization rules

`dialect sync` generates both from the canonical ARB:

```
dialect/source/en.arb → ios/en.lproj/Localizable.strings
                       → ios/en.lproj/Localizable.stringsdict (for plural keys)
```

**`.strings` output:**

```
/* CTA button on checkout screen, verb meaning 'make a reservation' */
"checkout_book_now" = "Book Now";

/* Generic loading indicator */
"common_loading" = "Loading...";
```

The `@description` from ARB becomes a comment in `.strings`, preserving context for developers reading the file in Xcode.

**`.stringsdict` output** (for keys with ICU plural expressions):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>checkout_item_count</key>
    <dict>
        <key>NSStringLocalizedFormatKey</key>
        <string>%#@count@</string>
        <key>count</key>
        <dict>
            <key>NSStringFormatSpecTypeKey</key>
            <string>NSStringPluralRuleType</string>
            <key>NSStringFormatValueTypeKey</key>
            <string>d</string>
            <key>one</key>
            <string>1 item</string>
            <key>other</key>
            <string>%d items</string>
        </dict>
    </dict>
</dict>
</plist>
```

### Key Conversion

Canonical ARB keys are flat camelCase (`checkoutBookNow`) and group via `@key.namespace` metadata. The iOS adapter prefixes the namespace and converts to `snake_case`: `checkout_book_now`. This matches Apple's conventions.

### ICU to .stringsdict Mapping

| ICU Category | .stringsdict Key | Notes |
|---|---|---|
| `=0` | `zero` | Exact match, mapped to zero category |
| `one` | `one` | Direct mapping |
| `two` | `two` | Used by Arabic, Welsh, etc. |
| `few` | `few` | Used by Slavic languages, Arabic |
| `many` | `many` | Used by Arabic, Polish, etc. |
| `other` | `other` | Required fallback |

Apple uses CLDR plural categories, same as ICU. The mapping is direct for category-based plurals. Exact selectors (`=1`, `=2`) are mapped to the corresponding CLDR category where possible.

### Config

```yaml
platforms:
  ios:
    output: ios/
    format: apple-strings
    namespaces: [common, mobile]
```

---

## Android (Kotlin) — out of v1 scope

**Priority: Reference only.** Dialect does **not** ship an `android-xml` adapter. Same reasoning as iOS above — Flutter handles strings via `AppLocalizations` for the Flutter UI layer. The sections below describe the conversion pattern if you need to hand-write `strings.xml` / `<plurals>` for native edge cases.

Translations ship with the app binary. OTA is not supported for Android native (resources are compiled at build time).

### Format

Android uses XML resource files:

- **`strings.xml`** — simple key-value strings
- **Inline `<plurals>` blocks** — plural forms within the same file

`dialect sync` generates locale-qualified resource directories:

```
dialect/source/en.arb → android/app/src/main/res/values/strings.xml
dialect/translations/es.arb → android/app/src/main/res/values-es/strings.xml
```

**Output:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- CTA button on checkout screen, verb meaning 'make a reservation' -->
    <string name="checkout_book_now">Book Now</string>

    <!-- Generic loading indicator -->
    <string name="common_loading">Loading…</string>

    <!-- Item count on checkout screen -->
    <plurals name="checkout_item_count">
        <item quantity="one">1 item</item>
        <item quantity="other">%d items</item>
    </plurals>
</resources>
```

The `@description` from ARB becomes an XML comment, preserving context.

### Key Conversion

Same as iOS: the flat camelCase ARB key is namespace-prefixed (from `@key.namespace`) and converted to `snake_case`. `checkoutBookNow` (namespace `checkout`) → `checkout_book_now`.

### ICU to Android Plurals Mapping

| ICU Category | Android `quantity` | Notes |
|---|---|---|
| `=0` | `zero` | Optional |
| `one` | `one` | |
| `two` | `two` | |
| `few` | `few` | |
| `many` | `many` | |
| `other` | `other` | Required fallback |

Android uses CLDR plural categories, same as ICU. The mapping is direct.

### Config

```yaml
platforms:
  android:
    output: android/app/src/main/res/
    format: android-xml
    namespaces: [common, mobile]
```

---

## JavaScript / TypeScript web

**Priority: supported, no adapter.** A web front end — SvelteKit, Next, Nuxt, Astro, plain Vite — reads `icu-json` directly. There is no `svelte-json`, `paraglide`, or `typesafe-i18n` adapter and there will not be one: those tools carry their own message formats and compilers, so an adapter would either lose ICU or fork the convention. This is [Backend Humility](platforms-backend.md#the-principle-backend-humility) applied to the front end.

### Config

```yaml
platforms:
  web:
    output: src/lib/locales/
    format: icu-json          # flat-json if the web slice has no plurals
    namespaces: [web, landing]
```

`dialect sync` writes `en.json`, `vi.json`, … as flat `key → value` objects. That is the entire integration on Dialect's side.

### Key safety without codegen

Flutter gets compile-time key checking from `gen-l10n`. The web gets the same thing from TypeScript, free, because the catalogue is a JSON module:

```ts
import en from '$lib/locales/en.json';

export type MessageKey = keyof typeof en;
```

A typo is now a compile error with a suggestion attached:

```
error TS2820: Type '"navFeeed"' is not assignable to type '"navFeed" | ... '.
Did you mean '"navFeed"'?
```

Shipping a `.d.ts` generator for this would be Dialect duplicating a compiler feature. Requires `"resolveJsonModule": true`, which every SvelteKit / Next / Vite tsconfig already sets.

### Formatting

Two lossless options, in order of preference:

1. **`Intl.PluralRules` and about forty lines.** Cardinal and ordinal plural selection is in every JavaScript runtime, browsers and edge workers included, and it is CLDR-correct for every locale the platform knows. A renderer covering `{placeholder}`, `plural`, `selectordinal`, `select`, `#`, and ICU's reduced apostrophe quoting fits in one small file with no dependency. Reference implementation: [`stepo-web/src/lib/i18n/format.ts`](https://github.com/ChauCM/dialect) (see the worked example below).
2. **`intl-messageformat`.** The reference ICU implementation, ~40 KB. Reach for it when messages use date/number skeletons or deeply nested expressions.

Do not hand-roll a formatter that "just does `{name}` replacement" over an `icu-json` catalogue. If the source carries plurals, that quietly renders the raw ICU expression to a user. Either implement the branches or configure the platform as `flat-json`, which collapses them deliberately and tells you which keys it collapsed.

### Tags become real HTML, and that is a hazard

The [rich-text convention](#rich-text-inside-one-sentence) puts inline tags like `<b>` inside a message so a styled run stays part of one translatable sentence. On Flutter those tags pass through a `TextSpan` parser that cannot execute anything. On the web, rendering them means `innerHTML` / `{@html}` / `dangerouslySetInnerHTML` — and many such messages interpolate somebody else's words: a display name, a journey title, a comment.

**The rule: format to a stream, not to a string.** The renderer must know which runs of output came from the message (yours, trusted, may carry tags) and which came from the arguments (not yours, always escaped). Concretely, give the formatter two hooks:

```ts
formatMessage(message, args, {
  locale,
  value:   escapeHtml,                              // arguments: always escaped
  literal: (text) => unwrapTags(escapeHtml(text)),  // message text: escaped, then the closed tag set restored
});
```

The tempting shortcut — concatenate everything, escape the result, then un-escape `&lt;b&gt;` back into `<b>` — is wrong, and wrong in a way tests rarely catch: a user whose display name is literally `<b>` gets their name turned into markup. Today that only breaks your layout. The day the tag set grows an attribute, it is an injection.

Keep the tag set closed and small, map each tag to an element plus a class supplied at the call site (the web equivalent of Flutter's tag → `TextStyle` map), and render anything outside the set as visible text. `dialect check`'s `tag_balance` rule already guarantees a translation carries exactly its source's tags, so the renderer can trust the shape and needs to police only the values.

### Choosing a language

Dialect has no opinion here, but three things are worth writing down because every web team meets them:

- **Negotiate once, on the server.** Resolve the locale in one place (a hook / middleware) and hand it to both the data layer and the render. The `<title>`, the `og:description` and the page body have to agree; a link preview in one language over a page in another is a visible bug.
- **`Vary: Accept-Language, Cookie`** on anything a CDN might cache, if one URL can answer in more than one language. Without it the first visitor's language is served to everyone behind that edge.
- **Never put the locale in module scope on an edge runtime.** Cloudflare Workers and similar share module state between concurrent requests, so a mutable "current locale" lets one request change another's language mid-render. Pass it through the request context (Svelte context, React context, an `AsyncLocalStorage`), not a module variable.

### Long-form documents are not keys

A privacy policy, terms of service, or community guidelines document is a document, not a string catalogue. Do not extract it into ARB keys: the key names are meaningless, the diffs are unreadable, and a clause that drifts between locales is worse than no translation. Keep them as per-locale files, translate them as documents, and say on the page which language governs. This belongs in the "What NOT to extract" list of your `dialect.yaml`.

---

## React Native

**Priority: out of scope.** React Native teams already have a mature `i18next` ecosystem. If RN sits alongside Flutter in one stack, the JavaScript guidance above applies unchanged — `icu-json` plus a formatter, no adapter.

---

## Platform Priority Summary

| Priority | Platform | Adapter ships? | OTA | Reasoning |
|---|---|---|---|---|
| **Primary** | Flutter | ✓ ARB copy | Deferred to v2.0+ (`dialect_ota`) | ARB is the universal source format; Flutter consumes it natively. Flutter's build produces iOS/Android binaries. |
| **Primary** | Backends | ✓ `icu-json` / `flat-json` (v1.1) | N/A — `dialect pull` + redeploy | Cross-stack Flutter ↔ backend sync is the core value prop |
| **Supported** | JS/TS web (SvelteKit, Next, Nuxt, …) | ✓ `icu-json` — the same one backends read | N/A — build-time import or `dialect pull` | A Flutter-led team's website is the third consumer of one source. No per-framework adapter needed: `Intl.PluralRules` + `keyof typeof` cover it. |
| Out of v1 scope | iOS (Swift) native | ✗ Not shipped | No (ships with binary) | Flutter handles iOS strings via its own build; only edge cases need hand-written `.strings`. See section above. |
| Out of v1 scope | Android (Kotlin) native | ✗ Not shipped | No (ships with binary) | Same as iOS. |
| Out of v1 scope | React Native | ✗ Not shipped | n/a | Existing `i18next` ecosystem already covers these teams |
