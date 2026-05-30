# Frontend Platforms

How Dialect integrates with frontend frameworks. **Flutter is the only first-class frontend target.**

> **Scope notice (2026-05).** Native iOS `.strings`/`.stringsdict` and native Android `strings.xml`/`<plurals>` adapters are **not on the roadmap**. Flutter generates iOS/Android-compatible output from `AppLocalizations` via its own build pipeline; standalone native string files only matter for edge cases (method channels, native plugins, launch screens). The sections below remain for reference — they describe the conversion patterns if you need to hand-write native files for those cases — but Dialect does not generate them automatically. See [`roadmap.md`](roadmap.md). React Native and React-web are likewise secondary; `i18next` alone covers their needs.

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

## React Native (Secondary)

Dialect generates i18next-compatible JSON for React Native via the `i18next-json` adapter. React Native teams already have a mature ecosystem with i18next, so Dialect is useful primarily when RN is part of a larger stack that includes Flutter, iOS/Android native, or backend services.

```yaml
platforms:
  react-native:
    output: src/locales/
    format: i18next-json
    key_style: nested_dot
    namespaces: [common, mobile]
```

The adapter converts ARB to i18next JSON: namespace prefixes become nested keys, ICU plurals become i18next suffixes (`_one`, `_other`), and placeholders convert from `{var}` to `{{var}}`. Basic plurals and interpolation are supported. `select`, `selectordinal`, plural `offset`, and nested ICU expressions are not supported and will error during conversion.

For OTA, use `i18next-http-backend` with `loadPath` pointing at per-locale JSON files. Persistent caching on-device requires `i18next-async-storage-backend` or a chained backend.

---

## React Web (Secondary)

Same adapter as React Native. Dialect generates i18next JSON. If your stack is React web without mobile apps, i18next's own ecosystem likely covers your needs without Dialect.

```yaml
platforms:
  react:
    output: web/public/locales/
    format: i18next-json
    key_style: nested_dot
    namespaces: [common, web]
```

---

## Platform Priority Summary

| Priority | Platform | Adapter ships? | OTA | Reasoning |
|---|---|---|---|---|
| **Primary** | Flutter | ✓ ARB copy | Deferred to v2.0+ (`dialect_ota`) | ARB is the universal source format; Flutter consumes it natively. Flutter's build produces iOS/Android binaries. |
| **Primary** | Backends | ✓ `icu-json` / `flat-json` (v1.1) | N/A — `dialect pull` + redeploy | Cross-stack Flutter ↔ backend sync is the core value prop |
| Out of v1 scope | iOS (Swift) native | ✗ Not shipped | No (ships with binary) | Flutter handles iOS strings via its own build; only edge cases need hand-written `.strings`. See section above. |
| Out of v1 scope | Android (Kotlin) native | ✗ Not shipped | No (ships with binary) | Same as iOS. |
| Out of v1 scope | React Native | ✗ Not shipped | n/a | Existing `i18next` ecosystem already covers these teams |
| Out of v1 scope | React Web | ✗ Not shipped | n/a | Same — `i18next` alone covers; revisit if demand surfaces |
