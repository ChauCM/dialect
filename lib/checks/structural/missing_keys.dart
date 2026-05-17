import '../../project/dialect_project.dart';
import '../rule.dart';

/// Every source key must exist (with a non-null value) in every target
/// locale's ARB file. Missing keys become untranslated holes in the
/// shipped app.
class MissingKeysRule extends Rule {
  const MissingKeysRule();

  @override
  String get name => 'missing_keys';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    final sourceKeys = project.source.entries.map((e) => e.key).toSet();

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      final arb = entry.value;
      final present = arb.entries.map((e) => e.key).toSet();
      for (final missing in sourceKeys.difference(present)) {
        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message: 'Missing translation for key `$missing`.',
            locale: locale,
            key: missing,
            file: arb.sourcePath,
            // No line — the key isn't in this file yet.
            hint:
                'Run `dialect translate` to backfill missing keys, '
                'or add the entry to ${arb.sourcePath} by hand.',
          ),
        );
      }
    }

    return issues;
  }
}
