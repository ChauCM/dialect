import '../../arb/icu_message.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Every placeholder (`{name}`) in the source value must appear in each
/// translation's value, and no new placeholders may be introduced.
/// Mismatches cause runtime ICU-format errors or unsubstituted braces in
/// the shipped UI.
class PlaceholderMatchRule extends Rule {
  const PlaceholderMatchRule();

  @override
  String get name => 'placeholder_match';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    for (final src in project.source.entries) {
      final sourcePh = IcuMessage.extractPlaceholders(src.value);

      for (final entry in project.translations.entries) {
        final locale = entry.key;
        final arb = entry.value;
        final translated = arb.entryFor(src.key);
        if (translated == null) continue; // covered by missing_keys

        final translatedPh = IcuMessage.extractPlaceholders(translated.value);
        final missing = sourcePh.difference(translatedPh);
        final extra = translatedPh.difference(sourcePh);

        if (missing.isNotEmpty) {
          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message:
                  'Translation drops placeholder(s) '
                  '${_listPlaceholders(missing)} for key `${src.key}`.',
              locale: locale,
              key: src.key,
              file: arb.sourcePath,
              line: arb.entryLines[src.key],
              hint:
                  'Preserve placeholder names byte-identically across '
                  'translations. Source has '
                  '${_listPlaceholders(sourcePh)}.',
            ),
          );
        }
        if (extra.isNotEmpty) {
          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message:
                  'Translation introduces unexpected placeholder(s) '
                  '${_listPlaceholders(extra)} for key `${src.key}`.',
              locale: locale,
              key: src.key,
              file: arb.sourcePath,
              line: arb.entryLines[src.key],
              hint:
                  'Use the exact placeholder names from the source — '
                  '${_listPlaceholders(sourcePh)}. Do not localize names.',
            ),
          );
        }
      }
    }

    return issues;
  }

  static String _listPlaceholders(Set<String> p) =>
      p.map((n) => '`{$n}`').join(', ');
}
