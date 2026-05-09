# Over-the-Air (OTA) Updates

Update translations without releasing a new app version. OTA is optional — the app always ships with bundled translations and works offline. OTA adds the ability to push fixes and new locales to users immediately.

---

## Protocol

The OTA protocol is a manifest file plus per-locale JSON files served from any HTTP endpoint.

### Manifest

```
GET {base_url}/dialect-manifest.json

{
  "version": "a1b2c3",
  "generated_at": "2026-04-02T12:00:00Z",
  "locales": {
    "en": "en.json",
    "es": "es.json",
    "ja": "ja.json"
  }
}
```

### Locale Files

```
GET {base_url}/es.json → translated strings for Spanish
```

The client package checks the manifest version against its cache. If newer, it downloads updated locale files.

---

## Flutter Package: `dialect_ota`

A custom `LocalizationsDelegate` that layers OTA translations on top of bundled ones.

### Setup

```yaml
# pubspec.yaml
dependencies:
  dialect_ota: ^0.1.0
```

### Configuration

```dart
MaterialApp(
  localizationsDelegates: [
    DialectLocalizationsDelegate(
      baseUrl: 'https://myapp.com/translations',
      fallback: AppLocalizations.delegate,
      checkInterval: Duration(hours: 1),
    ),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  // ...
)
```

### Resolution Order

1. OTA cached translations (if available and newer)
2. Bundled translations (always available, works offline)

### Disabling OTA

Set `enabled: false` or simply use the standard `AppLocalizations.delegate` without wrapping it.

---

## Publishing Translations

`dialect publish` generates a versioned bundle and pushes it to the configured adapter.

### Adapter: Local Filesystem

Output files to a folder. Serve them from your existing backend.

```yaml
# dialect.yaml
publish:
  adapter: local
  output: server/wwwroot/translations/
```

**ASP.NET MVC** — files land in `wwwroot/translations/`, served as static content.

**FastAPI / Python** — files land in a `/static/` folder, mounted to a route.

**Express / Node** — files land in a `public/translations/` folder.

### Adapter: GitHub

Commit to a release branch. Serve via GitHub Pages or raw URLs.

```yaml
publish:
  adapter: github
  branch: dialect-releases
```

### Adapter: HTTP

POST the translation bundle to any endpoint. Your backend receives it and stores it however you want.

```yaml
publish:
  adapter: http
  endpoint: https://myapi.com/admin/translations
  auth: "Bearer ${DIALECT_API_TOKEN}"
```

### Adapter: S3 / Cloud Storage

Upload to S3, Cloudflare R2, or GCS.

```yaml
publish:
  adapter: s3
  bucket: myapp-translations
  region: us-east-1
```

### Adapter: Dialect Cloud

Managed CDN with rollback, analytics, and A/B testing.

```yaml
publish:
  adapter: cloud
  project: acme-app
```

---

## Platform Support

| Platform | OTA Support | How |
|---|---|---|
| Flutter | Full | `dialect_ota` package with custom `LocalizationsDelegate` |
| iOS (Swift) | No | Translations ship with the binary. `NSLocalizedString` reads from the compiled bundle. |
| Android (Kotlin) | No | Translations ship with the binary. Resources are compiled at build time. |
| React / React Native | Via i18next | Use `i18next-http-backend` with `loadPath` pointing at per-locale JSON files |

---

## Versioning

Every `dialect publish` generates a content-addressable version hash. The manifest includes this version. The client compares it against its cached version and only downloads when there's a change.

```json
{
  "version": "a1b2c3",
  "generated_at": "2026-04-02T12:00:00Z",
  "locales": { ... }
}
```

Rollback is just publishing a previous version's files again.
