// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/glossary.yaml`.

// dart format off
const String glossaryYamlTemplate = r'''# ============================================================
# Project copy policy — Dialect convention
# ============================================================
# terms:   always say this. Terms with non-obvious or
#          domain-specific translations; `dialect check` verifies
#          that translations of strings containing them use the
#          prescribed translation.
# banned:  never say this. Literals or regexes that must not
#          appear in any value, the source locale included.
# style:   tone and formality, read by whoever (or whatever)
#          writes the translations rather than by a check.
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

# Copy this project does not ship. Checked against the source and
# every translation by the `banned_pattern` rule — a warning, so
# `dialect check --strict` is what turns it into a CI gate.
#
#   pattern:  the text to look for. Literal by default, so
#             punctuation needs no escaping.
#   reason:   required. Printed as the hint, so write what to do
#             instead, not a restatement of the pattern.
#   regex:    true to read `pattern` as a regular expression.
#   locales:  narrow it to some locales. Omit for all of them.
#   except:   keys ruled exempt for good.
#
# Two kinds of exception, for the two that copy policy has:
#   one use is right    → `dialect check --ack banned_pattern:LOCALE:KEY`,
#                         which expires when that value is next edited.
#   these keys are ruled exempt → `except:`, which survives an edit.
# The standing list is audited: a name in `except:` whose copy no
# longer holds the pattern is reported, so it can only shrink.
banned: []
  # - pattern: "—"
  #   reason: "Em-dashes are not used in this product's copy. Use a comma, a colon, or two sentences."
  #   except: [pushBodyJourneyFirstStep]
  # - pattern: '\b(utilize|leverage)\b'
  #   regex: true
  #   reason: "Prefer the plain verb: 'use'."
  #   locales: [en]

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
