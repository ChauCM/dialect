# Dialect i18next Integration Accuracy Review

Date: 2026-04-22  
Reviewer lens: i18next core maintainer

## Direct Answer for the GitHub Discussion

Dialect is **not a replacement for i18next** in the React/React Native path described here.  
It is a **build-time/source-of-truth layer** (ARB + sync/check tooling) that is intended to emit i18next JSON consumed by i18next at runtime.

So the right framing is: **Dialect works alongside i18next**.

## Scope Reviewed

- `README.md`
- `docs/architecture.md`
- `docs/platforms-frontend.md`
- `docs/platforms-backend.md`
- `docs/ota.md`
- `docs/thesis.md`

## High-Confidence Findings

### 1) The docs overstate completeness of the ARB -> i18next conversion

The conversion claims are only safe for a narrow subset of messages:

- plain strings
- simple interpolation (`{name}` -> `{{name}}`)
- basic plural keys that map cleanly to i18next plural suffixes

The docs present this as broadly solved, but they do not define a constrained ICU subset or fallback behavior for unsupported constructs.

### 2) ICU plural conversion claim is not semantically complete

Documented example:

- ICU: `{count, plural, =1{1 item} other{{count} items}}`
- i18next: `items_one` / `items_other`

This is not generally equivalent:

- ICU exact selectors (`=1`, `=0`, etc.) are exact-match semantics.
- i18next plural categories (`_one`, `_other`, `_few`, `_many`, etc.) are CLDR category semantics.
- Exact `=1` does not universally equal category `one` in all locales.

Concrete failure: in locales where CLDR `one` is not exactly value `1`, a direct `=1 -> _one` conversion can produce wrong output.

Also missing from the docs:

- `select`
- `selectordinal`
- plural `offset`
- nested ICU expressions

Those are common in production ICU catalogs and cannot be represented by plain i18next JSON plural suffix conversion without additional strategy.

### 3) Key-style story is internally inconsistent

`docs/architecture.md` defines canonical keys as `namespace.camelCaseKey` and shows examples like `checkout.bookNow` in ARB.  
`docs/platforms-frontend.md` then describes conversion as `checkoutBookNow -> checkout.bookNow`.

Those two statements imply different source key models:

- model A: source already uses dotted namespace keys
- model B: source is flat camelCase and converter introduces dots

Without one canonical rule, key conversion is ambiguous and teams will get mismatched lookups.

### 4) OTA guidance for i18next is inaccurate as written

The docs claim React can point `i18next-http-backend` at the same manifest endpoint used by Dialect OTA.

But the described OTA protocol is manifest-first (`dialect-manifest.json` -> locale file map), while `i18next-http-backend` expects direct resource URLs via `loadPath` unless custom logic is added.  
A custom backend adapter (or prefetch/transform layer) is needed to consume a manifest protocol.

### 5) "Built-in caching" claim is too broad

The docs imply i18next "already handles remote loading, caching, and fallback natively."  
Fallback behavior is core, but persistent caching behavior usually depends on backend/chained-backend setup and storage plugins, not just core defaults.

## Edge Cases Likely to Break

1. **Exact-value ICU selectors**  
   `=1`, `=2`, etc. converted to category suffixes will drift semantically in some locales.

2. **Arabic and other multi-form plurals**  
   If converter assumes only `_one/_other`, Arabic (`_zero/_one/_two/_few/_many/_other`) will be wrong.

3. **ICU `select` for gender/formality**  
   Native i18next handles context differently (`_male`, `_female`, etc.); direct ICU-to-plural conversion is insufficient.

4. **Plural offset and nested constructs**  
   ICU features such as `offset:1` have no direct equivalent in basic i18next suffix keys.

5. **Non-`count` plural variable names**  
   i18next plural resolution expects `count` option semantics; converter/runtime contract must be explicit or keys render incorrectly.

6. **Key separator collisions**  
   If generated keys include dots that should be literal, default key separator parsing will misresolve keys unless configuration is aligned.

7. **JSON compatibility/version mismatch**  
   Generated v4-style suffixes require modern plural handling; older compatibility modes and missing `Intl.PluralRules` support can break lookup.

## Production Readiness Verdict

As documented, the "canonical ARB -> i18next JSON" pipeline is **partially viable**, not production-complete.

- **Will work** for teams with simple strings and carefully constrained plural usage.
- **Will fail** for teams using real-world ICU breadth (exact selectors, select, nested ICU, offsets, locale-rich plural logic).

If this ships with the current claims, teams will likely hit conversion drift bugs and lose trust in the pipeline, especially after first multilingual edge-case incidents.

## Additional Reality Check: Repository State

`README.md` describes the architecture as a target design and references planning status, and this repository snapshot contains docs but no converter/runtime implementation to validate behavior against fixture tests.

So production claims are currently documentation-level assertions, not implementation-proven guarantees.

## What To Change Before Claiming "Production-Ready i18next Integration"

1. Define and publish a strict supported ICU subset for `i18next-json` output.
2. Emit hard errors (not silent conversion) for unsupported ICU constructs.
3. Add fixture-based round-trip tests across locales (English, French, Arabic minimum).
4. Clarify one canonical key model (already dotted vs camelCase-to-dot transform).
5. Document required i18next runtime config (plural rules/polyfills, key separators, namespaces).
6. For full ICU semantics, prefer preserving ICU and using an ICU-capable runtime strategy rather than lossy conversion.

## Bottom Line

Dialect should be presented to the developer as:

- **Source-of-truth + conversion toolchain** that complements i18next
- not a replacement runtime
- and currently reliable only for a constrained subset unless the conversion contract is narrowed and enforced
