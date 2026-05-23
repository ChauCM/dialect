import '../../arb/arb_file.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// For each entry whose source value contains a glossary term, every
/// target translation must contain a recognizable form of the canonical
/// translation. Honors `@key.glossary_exempt: true` on the SOURCE entry
/// (the escape hatch for non-literal uses, e.g. "Book club" where
/// "Book" means a physical book, not the verb).
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
/// by setting `@key.glossary_exempt: true`; the warning hint says so.
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
        if (src.metadata?.glossaryExempt == true) continue;

        for (final term in project.glossary.terms) {
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
                  'add `"glossary_exempt": true` to the @key block in the '
                  'source ARB.',
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
  static bool _sourceContainsTerm(String source, String term) {
    final normalized = term.toLowerCase();
    return _tokenize(source).contains(normalized);
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
