# Mobile Platforms

How Dialect integrates with each mobile framework — format conversion, OTA support, and platform-specific considerations.

---

## Flutter

**Priority: Primary.** Flutter is the home audience. ARB is the canonical format, so the adapter is trivial.

### Format

Dialect's canonical ARB is Flutter's native format. `dialect sync` copies the file as-is.

```
dialect/source/en.arb → lib/l10n/app_en.arb
dialect/translations/es.arb → lib/l10n/app_es.arb
```

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
      *adds keys with @descriptions to en.arb (e.g. checkout.bookNow)*
      *translates to es.arb*
      *rewrites widget to use AppLocalizations.of(context).checkout_bookNow*
```

---

## iOS (Swift)

**Priority: Primary.** iOS localization DX is painful — `.strings` files are manual, `.stringsdict` XML is verbose, and there's no cross-platform sync story. Dialect solves this with format sync from the canonical ARB source.

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

Canonical ARB keys use `namespace.camelCase` (e.g., `checkout.bookNow`). The iOS adapter converts to `snake_case` with underscore separators: `checkout_book_now`. This matches Apple's conventions.

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

## Android (Kotlin)

**Priority: Primary.** Same value proposition as iOS — Android's XML resource files are verbose and manual, and there's no cross-platform sync.

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

Same as iOS: `namespace.camelCase` → `snake_case` with underscores. `checkout.bookNow` → `checkout_book_now`.

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

| Priority | Platform | Format Adapter | OTA | Reasoning |
|---|---|---|---|---|
| Primary | Flutter | Trivial (ARB copy) | Full (`dialect_ota`) | Home audience, native format |
| Primary | iOS (Swift) | `.strings` + `.stringsdict` | No (ships with binary) | Painful DX, high sync value |
| Primary | Android (Kotlin) | `strings.xml` + `plurals` | No (ships with binary) | Same story as iOS |
| Primary | Backends | See [Backend Platforms](platforms-backend.md) | N/A | Cross-platform sync is the core value prop |
| Secondary | React Native | i18next JSON | Via i18next-http-backend | Existing i18next ecosystem covers most needs |
| Secondary | React Web | i18next JSON | Via i18next-http-backend | Same — supported as output, not the target audience |
