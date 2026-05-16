// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/glossary.yaml`.

// dart format off
const String glossaryYamlTemplate = r'''# ============================================================
# Project glossary — Dialect convention
# ============================================================
# Terms with non-obvious or domain-specific translations.
# `dialect check` verifies that translations of strings
# containing these terms use the prescribed translation.
#
# Escape hatch: if a string uses a term in a non-literal sense
# (e.g. "Book club" really means a physical book), mark the
# key with @key.glossary_exempt: true in the source ARB.
# ============================================================

terms:
  - term: "Book"
    meaning: >
      (Example) Verb meaning 'make a reservation', NOT a physical
      book. Replace or delete this entry once you've added your
      project's first real glossary term.
    translations:
      es: "Reservar"
      ja: "予約する"

style:
  # Project-wide tone. Short phrase; "friendly, concise" is a good default.
  tone: "friendly, concise"

  # Per-locale formality. Use the form your AI assistant should produce.
  formality: {}
    # es: "tú (informal)"
    # de: "Sie (formal)"
    # ja: "です/ます (polite)"

  # Rules of thumb that apply across every locale.
  general:
    - "Preserve all ICU placeholders ({name}, {count}, etc.) exactly as in source."
    - "Preserve all plural categories ICU expects for the target locale."
    - "Do not translate brand names, currency symbols, or units."
''';
// dart format on
