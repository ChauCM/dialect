## Localization (Dialect)

This project uses [Dialect](https://dialect.tools) for localization.

**When the developer asks you to add or update translations:**

1. Read `dialect/dialect.yaml` for the convention — key naming
   (flat camelCase + `@key.namespace` metadata), target locales,
   plural rules, and the "What NOT to extract" list.
2. Read `dialect/glossary.yaml` for prescribed translations of
   project-specific terms.
3. Add or edit keys in `dialect/source/{{SOURCE_LOCALE}}.arb` and the
   per-locale translation files under `dialect/translations/`. Generate
   every target locale's value in the same turn — translators review
   AI-generated translations, they don't fill blanks. If keys are already
   missing translations (e.g. after an import), run `dialect translate`
   to get a per-locale work list of exactly what to fill.
4. Replace hardcoded strings in source code with the platform's
   localized accessor — for Flutter, `AppLocalizations.of(context)!.<key>`.
5. Run `dialect check --fix && dialect sync && dialect check` to
   normalize, generate platform output, and validate.

**Flutter codegen.** `flutter gen-l10n` reads `lib/l10n/`. Run
`flutter pub get` after `dialect sync` to regenerate `AppLocalizations`.

**Cross-stack sync.** If a backend platform is configured in
`dialect.yaml` (`format: icu-json` or `flat-json`), `dialect sync` also
writes `<locale>.json` for it from the same source — keep the Flutter app
and backend in sync from one canonical ARB.

**Pending initial setup.** If `.dialect/init-plan.md` exists, that's
the developer's pending onboarding playbook — execute Phase 1 first.
The trigger phrase `start translation phase` advances it to Phase 2.
