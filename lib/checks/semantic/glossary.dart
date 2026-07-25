import '../../arb/arb_file.dart';
import '../../arb/icu_message.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// For each entry whose source value contains a glossary term, every
/// target translation must contain a recognizable form of the canonical
/// translation.
///
/// The escape hatch for non-literal uses (e.g. "Book club", where "Book"
/// means a physical book rather than the verb) is `@key.glossary_exempt`
/// on the SOURCE entry, in either of two shapes:
///
/// ```jsonc
/// "glossary_exempt": ["take", "sentence"]   // waive exactly these terms
/// "glossary_exempt": true                    // waive every term (blunt)
/// ```
///
/// The list form is preferred and is what the hint suggests. One string can
/// use two locked terms non-literally for two different, both-correct
/// reasons while still needing the rest of the glossary applied — the
/// blanket `true` silently waives those too, and it tells a reviewer
/// nothing about *what* was waived, which is precisely what a waiver should
/// make visible.
///
/// Match strategy (deliberately a heuristic — this is a warning):
///   - Source side: whole-word case-insensitive match of `term` against
///     a word-tokenized source value.
///   - Translation side: case-insensitive substring match of a prefix
///     of the canonical translation. The prefix is the lowercased
///     canonical with the last 2 chars dropped when length > 4 (handles
///     suffix-based inflection: "Reservar" → search "reserv", which
///     also matches "Reserva"/"Reservamos"/"Reservación"). Languages
///     with little suffix inflection (CJK) get the full canonical.
///
/// The match is intentionally permissive. False positives are dismissed
/// per-term via `@key.glossary_exempt`; the warning hint says so, and
/// names the specific term to add.
class GlossaryRule extends Rule {
  const GlossaryRule();

  @override
  String get name => 'glossary';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    if (project.glossary.terms.isEmpty) return issues;

    final sourceByKey = <String, ArbEntry>{
      for (final e in project.source.entries) e.key: e,
    };

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      if (locale == project.config.sourceLocale) continue;
      final arb = entry.value;

      for (final t in arb.entries) {
        final src = sourceByKey[t.key];
        if (src == null) continue;

        for (final term in project.glossary.terms) {
          // Exemptions are per-term: a key excused from "take" still has to
          // honor every other locked term in the same string.
          if (src.metadata?.exemptFrom(term.term) ?? false) continue;
          if (!_sourceContainsTerm(src.value, term.term)) continue;
          final canonical = term.translations[locale];
          if (canonical == null) continue; // glossary doesn't cover this locale
          if (_translationContainsCanonical(t.value, canonical)) continue;

          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message:
                  'Translation for `${t.key}` does not appear to use the '
                  'glossary term "${term.term}" (expected something like '
                  '"$canonical").',
              locale: locale,
              key: t.key,
              file: arb.sourcePath,
              line: arb.entryLines[t.key],
              hint:
                  'Glossary defines "${term.term}" → "$canonical" in `$locale`. '
                  'If this key uses "${term.term}" in a non-literal sense, '
                  'add `"glossary_exempt": ["${term.term}"]` to the @key '
                  'block in the source ARB — a list waives only the terms it '
                  'names, so the rest of the glossary still enforces here. '
                  '(`true` waives every term on this key; prefer the list, '
                  'since a diff can then show what was actually waived.)',
            ),
          );
        }
      }
    }

    return issues;
  }

  /// Whole-word, case-insensitive match against an ASCII-tokenized
  /// source value. The term is expected to be the canonical English
  /// form; ASCII matching is enough for the v1.0 target audience.
  ///
  /// Scans only the *literal* copy — placeholder names are excluded
  /// ([IcuMessage.literalText]) so a term that appears only as `{term}`
  /// (e.g. `"Step · {journey}"`) doesn't demand translation.
  static bool _sourceContainsTerm(String source, String term) {
    final normalized = term.toLowerCase();
    return _tokenize(IcuMessage.literalText(source)).contains(normalized);
  }

  /// True when [translation] contains a recognizable prefix of
  /// [canonical] (case-insensitive). For canonicals longer than 4
  /// chars, the prefix drops the last 2 chars to tolerate suffix
  /// inflection. For ≤4-char canonicals (mostly CJK), the full form
  /// is required.
  static bool _translationContainsCanonical(
    String translation,
    String canonical,
  ) {
    final tLower = translation.toLowerCase();
    final cLower = canonical.toLowerCase();
    final prefix = cLower.length > 4
        ? cLower.substring(0, cLower.length - 2)
        : cLower;
    return tLower.contains(prefix);
  }

  static Set<String> _tokenize(String value) {
    final out = <String>{};
    final buf = StringBuffer();
    for (final c in value.toLowerCase().codeUnits) {
      final isAlpha =
          (c >= 0x61 && c <= 0x7A) || // a-z
          (c >= 0x30 && c <= 0x39); // 0-9
      if (isAlpha) {
        buf.writeCharCode(c);
      } else {
        if (buf.isNotEmpty) {
          out.add(buf.toString());
          buf.clear();
        }
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }
}
