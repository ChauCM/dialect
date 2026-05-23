import '../../arb/arb_file.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Warn when a translation contains a clearly English function word
/// that wouldn't appear in any of the supported target languages
/// naturally. A conservative heuristic: false negatives are common
/// (the rule only catches a narrow class of misses), but false
/// positives are rare — every word on the list is unambiguous.
///
/// Function-word list is deliberately tight. We exclude words like
/// `for` and `to`, which collide with Romance language tokens, and
/// `is`/`a`, which appear in many languages as short tokens.
///
/// Carryover guard: if the same word appears in the source string
/// (likely a brand name or technical term that flows through to
/// translations), the rule skips it. Example: "Subscribe to the New
/// York Times" in source → "the" is OK in any locale.
class UntranslatedEnglishRule extends Rule {
  const UntranslatedEnglishRule();

  /// English function words unlikely to appear in any of the v1.0
  /// target locales (es, ja, ar, de, vi). Whole-word, case-insensitive
  /// match. Bias: under-flag, never wrongly flag.
  static const Set<String> englishFunctionWords = {
    'the',
    'and',
    'with',
    'this',
    'that',
    'you',
  };

  @override
  String get name => 'untranslated_english';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    final sourceLocale = project.config.sourceLocale;
    if (sourceLocale != 'en') return issues; // heuristic is English-only

    final sourceByKey = <String, ArbEntry>{
      for (final e in project.source.entries) e.key: e,
    };

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      if (locale == sourceLocale) continue;
      final arb = entry.value;

      for (final t in arb.entries) {
        final src = sourceByKey[t.key];
        if (src == null) continue;
        final sourceWords = _words(src.value);

        for (final word in _words(t.value)) {
          if (!englishFunctionWords.contains(word)) continue;
          if (sourceWords.contains(word)) continue; // carryover
          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message:
                  'Translation for `${t.key}` contains English function '
                  'word "$word".',
              locale: locale,
              key: t.key,
              file: arb.sourcePath,
              line: arb.entryLines[t.key],
              hint:
                  'Likely a partially-translated string. Re-translate or, '
                  'if "$word" appears as part of a brand or technical term '
                  'that should pass through, surface it in the source too.',
            ),
          );
          break; // one issue per entry is enough — report a sample, not every match
        }
      }
    }

    return issues;
  }

  /// Lowercased word tokens. Word boundaries are Unicode-aware in
  /// spirit but ASCII-aware in implementation: we split on anything
  /// that isn't a Latin letter, which is fine since the function-word
  /// list is ASCII-only.
  static Set<String> _words(String value) {
    final out = <String>{};
    final buf = StringBuffer();
    for (final c in value.toLowerCase().codeUnits) {
      final isLetter =
          (c >= 0x61 && c <= 0x7A) || // a-z
          (c >= 0x30 && c <= 0x39); // 0-9 (keep words like "html5")
      if (isLetter) {
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
