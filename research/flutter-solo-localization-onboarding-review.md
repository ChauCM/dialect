# Dialect Onboarding Review (Solo Flutter First App Lens)

Date: 2026-04-22  
Persona: Solo Flutter developer, first app, 3 target languages, never used ARB before

## Scope Reviewed

- `README.md`
- `docs/architecture.md`
- `docs/platforms-frontend.md`
- `docs/platforms-backend.md`
- `docs/ota.md`
- `docs/thesis.md`

## Verdict: Approachable or Intimidating?

The onboarding is **mixed**: technically clear, but emotionally intimidating for a first-time localizer.

- **Approachable:** The Flutter path itself is straightforward once you see it (`ARB in -> ARB out`, plus `dialect sync` and `dialect check`).
- **Intimidating:** The docs quickly broaden into a full localization architecture (namespaces, adapters, CI, review UI, OTA, multi-platform outputs). For a solo first app, that feels like adopting a system, not just translating one string.

If I were truly new to localization, this would feel like a **7/10 intimidation level** despite good documentation quality.

## Concept Count Before First Translated String

From the listed concepts, I would need to learn **3 out of 7** before translating my first string in a way that matches the toolkit's conventions.

### Required up front (3)

1. **ARB** - Required. I need to understand ARB shape (`@@locale`, keys, and `@key` metadata).
2. **Namespaces** - Practically required because key naming conventions are central (`namespace.camelCase`) and used throughout examples/config.
3. **Adapters** - Required at a basic level to understand what `dialect sync` does, even if Flutter is a trivial adapter.

### Can defer until later (4)

4. **ICU MessageFormat** - Not required for the first simple string; required only once plurals/select/gender appear.
5. **Glossary** - Helpful for consistency, but optional for first translation.
6. **Split-file architecture** - Scale feature; unnecessary for initial onboarding.
7. **OTA** - Explicitly optional; not needed to ship v1 translations.

## What Works Well for a New Flutter Dev

- Flutter is treated as first-class and ARB-native, which keeps the platform path coherent.
- Command surface is memorable (`init`, `sync`, `check` as the core loop).
- Metadata examples (`@description`, placeholders) make translation context tangible.

## What Raises Friction

- The initial framing introduces many advanced capabilities before the first "hello world" translation flow is fully isolated.
- The mental model includes policy decisions (namespaces, sorted keys, canonical source of truth) that feel heavy for a one-person app.
- README messaging includes "active design/target architecture" language, which can reduce trust for someone expecting a clearly "already shipped" tool.

## Honest Adoption Decision

For my first Flutter app with only 3 languages, I would probably **hardcode a simple `Map<String, String>` or use vanilla Flutter localization first**, then adopt Dialect later.

I would switch to Dialect when one of these becomes true:

- I add a second platform (web/backend) and need sync guarantees.
- I start changing copy frequently and want AI-assisted translation deltas.
- Non-developers need review/edit workflows.

## Bottom Line

Dialect looks strong for teams or projects that expect localization to scale. For a solo Flutter beginner shipping fast, onboarding currently feels more powerful than necessary for day-one needs.
