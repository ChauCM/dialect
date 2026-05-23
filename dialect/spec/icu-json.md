# `icu-json` — Backend JSON Output (Plurals Preserved)

**Status:** v1.0. Stable contract. Breaking changes require a major-version bump and a migration note in `CHANGELOG.md`.

**Owners:** `dialect sync` (v1.1+ — writes), `Dialect.AspNetCore` NuGet (v1.1 — reads), any third-party backend localizer (`i18next-fs-backend`, `go-i18n`, `babel.support.Translations`, …) — reads.

---

## What it is

`icu-json` is one of two backend output formats Dialect emits (the other is [`flat-json`](./flat-json.md)). It preserves the full ICU MessageFormat expression — plural, select, selectordinal — byte-identically from the canonical ARB. Backend code reads the resulting `<locale>.json` files through an ICU-aware library (`MessageFormat.NET`, `intl-messageformat`, `babel`, …) and renders the right plural/select branch at request time.

Use `icu-json` when your backend strings need pluralization, gender, or other locale-aware rendering. Use [`flat-json`](./flat-json.md) when they don't — `flat-json` is simpler to consume but loses plural logic.

`icu-json` lives behind [Backend Humility](../../planning/competitive-strategy.md#backend-humility): backend engineers keep their stack's native localization interface (`IStringLocalizer<T>` / `_()` / `i18next.t`), they just point it at a JSON file instead of `.resx` / `.po` / a database.

---

## File layout

```
<platform.output>/
  en.json
  es.json
  ja.json
  ar.json
  …
```

- One file per locale. Filename is `<locale>.json` where `<locale>` is the IETF BCP 47 tag from `dialect.yaml` (e.g. `en`, `pt-BR`).
- The `output` directory is read from `platforms.<p>.output` in `dialect.yaml`. Dialect creates it if missing.
- No index file, manifest, or directory listing — backend libraries discover files by locale.

---

## File shape

Each file is a UTF-8 encoded JSON object with **flat string keys**:

```json
{
  "checkout.bookNow": "Book Now",
  "checkout.itemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "common.cancel": "Cancel"
}
```

| Decision | Value |
|---|---|
| Top-level | JSON object (`{ … }`). Never an array, never a primitive. |
| Keys | The ARB key verbatim (e.g. `checkout.bookNow`). Dots are part of the key, not a nesting separator. |
| Values | UTF-8 strings. ICU MessageFormat expressions are preserved verbatim. |
| Encoding | UTF-8, NFC-normalized. No BOM. |
| Indentation | 2 spaces, LF line endings, trailing newline at EOF. |
| Sort order | Keys sorted lexicographically (codepoint order). |
| `@@`-metadata | **Not emitted.** `@@locale` and friends are ARB-only. The locale is in the filename. |
| `@key` blocks | **Not emitted.** Metadata lives in the source ARB; backends don't read it. |
| Unknown keys | Backend libraries should return the key itself as a fallback. Dialect does not write a marker for "missing translation"; the file simply omits the key. |

### Why flat keys (not nested objects)

Nested keys (`{ "checkout": { "bookNow": "Book Now" } }`) require picking a separator and re-segmenting at read time. ARB keys are already dotted strings, and every backend library Dialect targets (`i18next`, `go-i18n`, `IStringLocalizer<T>`, `babel`) accepts flat dotted keys natively. Flat keys also keep the JSON file diff-friendly: adding a key under `checkout.*` doesn't reflow the entire `checkout` block.

---

## Placeholder rules

Placeholders use ICU MessageFormat syntax exactly as in the source ARB:

```json
{
  "checkout.welcome": "Hello {userName}!",
  "checkout.total": "Total: {amount, number, currency}"
}
```

- Placeholder names are preserved byte-identically. The M4 `placeholder_match` rule already enforces this on every translation; the writer just passes through.
- Type/format declarations in `@key.placeholders` (from the source ARB) are **not** emitted into the JSON. They're translator-facing metadata; the backend's ICU library infers types at render time.

---

## Plural / select / selectordinal handling

`icu-json` preserves plural, select, and selectordinal expressions verbatim:

```json
{
  "checkout.itemCount":
    "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
  "profile.greeting":
    "{gender, select, female{Welcome back} male{Welcome back} other{Welcome}}"
}
```

Including locales with non-trivial plural rules (Arabic has six CLDR categories: zero/one/two/few/many/other):

```json
{
  "checkout.itemCount":
    "{count, plural, =0{لا توجد عناصر} =1{عنصر واحد} zero{لا توجد عناصر} one{عنصر واحد} two{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}"
}
```

This is the format every ICU MessageFormat library accepts. No flattening, no transformation.

---

## Namespace handling

Namespaces are the prefix before the first dot in a key (e.g. `checkout` in `checkout.bookNow`). The CLI uses `platforms.<p>.namespaces` to decide which keys sync to which platform. The emitted JSON is platform-scoped: a backend platform with `namespaces: [common, backend]` only sees keys with those prefixes.

`namespaces: []` means "every key syncs" — useful for a single-platform project.

Namespaces are **not** encoded as nested objects in the JSON output. They're just key prefixes.

---

## Idempotency

Running `dialect sync` twice with no source changes produces byte-identical files on disk. Keys are sorted deterministically, values are passed through verbatim, formatting (2-space indent, LF, trailing newline) is fixed. The M5 `_maybeWrite` skip applies: if the desired bytes match disk, the file isn't rewritten and mtime is preserved.

---

## Worked example

**Source ARB** (`dialect/source/en.arb`):

```json
{
  "@@locale": "en",
  "checkout.bookNow": "Book Now",
  "@checkout.bookNow": {
    "description": "CTA on the checkout screen.",
    "placeholders": {}
  },
  "checkout.itemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "@checkout.itemCount": {
    "description": "Cart summary line.",
    "placeholders": { "count": { "type": "int" } }
  },
  "common.cancel": "Cancel"
}
```

**`dialect.yaml`**:

```yaml
source_locale: en
target_locales: [es, ar]
platforms:
  backend:
    output: api/locales/
    format: icu-json
    namespaces: [common, checkout]
```

**Output for `en` (`api/locales/en.json`)**:

```json
{
  "checkout.bookNow": "Book Now",
  "checkout.itemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "common.cancel": "Cancel"
}
```

**Output for `ar` (`api/locales/ar.json`)** — same shape, Arabic values, every CLDR plural category present:

```json
{
  "checkout.bookNow": "احجز الآن",
  "checkout.itemCount":
    "{count, plural, =1{عنصر واحد} zero{لا توجد عناصر} one{عنصر واحد} two{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}",
  "common.cancel": "إلغاء"
}
```

Note what's gone: the `@@locale`, the `@key` metadata, and the `@checkout.itemCount` placeholders block. Those are ARB-side concerns. The backend just needs the string contract.

---

## Library notes

Dialect commits to this contract; the implementer of any consuming library can rely on the shape above. Some pointers for common stacks:

- **ASP.NET (C#)**: `Dialect.AspNetCore` (v1.1) implements `IStringLocalizer<T>` over `icu-json` and pulls in `Jeffijoe/messageformat.net` for ICU evaluation. Callsites use the standard `_localizer["checkout.bookNow"]` API.
- **Node**: `i18next-fs-backend` reads flat-key JSON directly. Wrap lookups in `intl-messageformat` for ICU rendering.
- **Python / Django / Flask**: `babel.support.Translations.fromfile` for the JSON, then `babel.messages.mofile` or a small ICU wrapper for plurals.
- **Go**: `go-i18n` consumes flat-key JSON natively and parses ICU plurals out of the box.

These are documented under `docs/platforms-backend.md` and are intentionally **not** maintained by Dialect — see Backend Humility.

---

## Out of scope for v1.0

- Multi-source-ARB projects. v1.0 has exactly one source ARB.
- Nested-object output (`{ "checkout": { … } }`). Flat keys only.
- Locale fallback chains in the JSON itself (`en-US` falling back to `en`). The backend library handles fallback; Dialect emits one file per declared locale.
- Compression, minification, or binary encodings. Plain JSON; the file is part of the deploy artifact, not the wire format.
- A schema declaration inside each file (`$schema`, version stamp). The contract is the spec at `dialect/spec/icu-json.md`; Dialect's CLI version owns compatibility.
