# `flat-json` — Backend JSON Output (Plurals Stripped)

**Status:** v1.0. Stable contract. Breaking changes require a major-version bump and a migration note in `CHANGELOG.md`.

**Owners:** `dialect sync` (v1.1+ — writes), any backend localizer that consumes plain JSON without an ICU evaluator (`i18next-fs-backend` with no plural plugin, `babel.support.Translations` reading messages.json, simple `string.Format` flows).

---

## What it is

`flat-json` is the simpler of Dialect's two backend output formats (the other is [`icu-json`](./icu-json.md)). It strips ICU MessageFormat plural / select / selectordinal expressions down to a single plain string — taking the `other` branch deterministically — so a backend with no ICU runtime can still consume Dialect translations through plain interpolation.

Use `flat-json` for:

- Error messages, validation messages, notification titles
- API responses with no plural or gender logic
- Stacks that can't add an ICU dependency

Use [`icu-json`](./icu-json.md) for everything else.

`flat-json` lives behind [Backend Humility](../../planning/competitive-strategy.md#backend-humility): we don't ship a custom adapter for stacks that only want "key → string" — JSON is already universal.

---

## File layout

Identical to `icu-json`:

```
<platform.output>/
  en.json
  es.json
  …
```

- One file per locale. Filename is `<locale>.json` where `<locale>` is the IETF BCP 47 tag from `dialect.yaml`.
- `output` is read from `platforms.<p>.output`.

---

## File shape

A UTF-8 encoded JSON object with **flat string keys** and **plain string values**:

```json
{
  "checkout.bookNow": "Book Now",
  "checkout.itemCount": "{count} items",
  "common.cancel": "Cancel"
}
```

| Decision | Value |
|---|---|
| Top-level | JSON object. Never an array, never a primitive. |
| Keys | The ARB key verbatim (e.g. `checkout.bookNow`). Flat dotted keys, never nested. |
| Values | Plain strings. ICU expressions are stripped per the rules below; no `{count, plural, …}` ever appears. Simple `{placeholder}` substitution survives. |
| Encoding | UTF-8, NFC-normalized. No BOM. |
| Indentation | 2 spaces, LF line endings, trailing newline at EOF. |
| Sort order | Keys sorted lexicographically (codepoint order). |
| `@@`-metadata, `@key` blocks | Not emitted. |
| Unknown keys | Omitted from the file; backends return the key as a fallback. |

The file shape is intentionally identical to `icu-json` except for the value content. A backend can switch between formats by changing one line in `dialect.yaml` without touching application code that does the JSON load.

---

## Placeholder rules

Simple `{placeholder}` substitution survives:

```json
{
  "common.welcome": "Welcome, {userName}"
}
```

A backend renders this with whatever string-interpolation library it already has (`string.Format`, `str.format`, template literals, etc.). Placeholder names are preserved byte-identically from the ARB.

ICU type/format suffixes (`{amount, number, currency}`, `{when, date, short}`) are stripped to bare `{amount}` / `{when}` — backends that need locale-aware number/date formatting should use `icu-json` instead.

---

## Plural / select / selectordinal stripping

The defining behaviour of `flat-json`: ICU plural/select/selectordinal expressions are flattened to a single string by taking the `other` branch and recursively stripping any nested ICU expressions inside it.

### Plural

Source ARB:

```json
"checkout.itemCount":
  "{count, plural, =0{No items} =1{1 item} other{{count} items}}"
```

`flat-json` output:

```json
"checkout.itemCount": "{count} items"
```

Rule: take the body of the `other` branch verbatim, recursively strip any inner ICU expressions, leave plain `{placeholder}` tokens intact.

The `=N` exact-match branches and the locale-specific CLDR categories (`one`/`two`/`few`/`many`) are discarded. The reviewer sees this in the M4 `placeholder_match` check, and the sync log emits an info-level note ("`checkout.itemCount` plural → `other` branch").

### Select

Source ARB:

```json
"profile.greeting":
  "{gender, select, female{She booked your stay} male{He booked your stay} other{They booked your stay}}"
```

`flat-json` output:

```json
"profile.greeting": "They booked your stay"
```

Rule: same as plural — take the `other` branch, recursively strip.

### Selectordinal

Same rule as plural — take the `other` branch.

### Nested expressions

Nested ICU expressions inside the `other` branch are recursively stripped:

Source ARB:

```json
"social.replies":
  "{count, plural, =1{1 reply by {user, select, female{her} male{him} other{them}}} other{{count} replies}}"
```

`flat-json` output:

```json
"social.replies": "{count} replies"
```

Only the outermost `other` body survives, and any nested ICU inside it gets the same treatment.

### Validation: missing `other` branch

ICU requires plurals to have an `other` branch; `flat-json` requires it for plural, select, and selectordinal. If a source value is missing one, the writer aborts with a `FormatException` pointing at the file:line, and `dialect sync` exits non-zero. The structural check rule under `lib/checks/structural/plural_categories.dart` catches this earlier in normal use.

---

## Namespace handling

Identical to [`icu-json`](./icu-json.md): keys are filtered by `platforms.<p>.namespaces` before serialisation; namespaces are key prefixes, not nested objects.

---

## Idempotency

Running `dialect sync` twice with no source changes produces byte-identical files on disk — same sort order, formatting, plural-stripping rule.

---

## Worked example

**Source ARB** (`dialect/source/en.arb`):

```json
{
  "@@locale": "en",
  "checkout.bookNow": "Book Now",
  "checkout.itemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "profile.greeting": "{gender, select, female{Welcome back} male{Welcome back} other{Welcome}}",
  "common.cancel": "Cancel"
}
```

**`dialect.yaml`**:

```yaml
source_locale: en
target_locales: [es]
platforms:
  api-gateway:
    output: gateway/locales/
    format: flat-json
    namespaces: [common, checkout, profile]
```

**Output for `en` (`gateway/locales/en.json`)**:

```json
{
  "checkout.bookNow": "Book Now",
  "checkout.itemCount": "{count} items",
  "common.cancel": "Cancel",
  "profile.greeting": "Welcome"
}
```

Note: the plural collapsed to `{count} items`; the select collapsed to `Welcome`; everything else passes through verbatim.

**Output for `es`** has the same structure with Spanish strings:

```json
{
  "checkout.bookNow": "Reservar ahora",
  "checkout.itemCount": "{count} elementos",
  "common.cancel": "Cancelar",
  "profile.greeting": "Bienvenido"
}
```

The Spanish source plural `{count, plural, one{1 elemento} other{{count} elementos}}` collapsed to `{count} elementos`. The grammatical "1 elemento" branch is permanently lost in this format — that's the documented trade-off.

---

## Loss-of-information warning

`flat-json` is lossy. Once the plural / select information is stripped, you cannot recover it from the JSON output. If your backend later needs "1 item" vs "5 items", you must:

1. Re-emit from the source ARB with `format: icu-json`, and
2. Plug an ICU runtime into your backend.

Dialect's `dialect sync` does **not** reverse-engineer plural rules from a `flat-json` output. The source ARB is the single source of truth; backend artefacts are deliberately downstream.

The CLI surfaces this trade-off when a project's source uses plural / select expressions and a `flat-json` platform is configured — a single line per affected key, at sync time, level `info`, suppressible:

```
info: gateway/locales/  flat-json strips plurals for: checkout.itemCount, profile.greeting
  hint: switch this platform to `format: icu-json` if those keys need locale-correct plurals.
```

---

## Out of scope for v1.0

- A configurable "which branch wins" strategy. `other` is the only choice in v1.0; we revisit if there's real demand.
- A separate `--strict-plural` flag for `flat-json` (fail sync if plurals exist instead of silently stripping). The info hint is the v1.0 answer; users who want hard failures use `format: icu-json` instead.
- Multi-source-ARB projects.
- Locale fallback chains in the JSON.
