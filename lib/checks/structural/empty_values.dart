import '../../project/dialect_project.dart';
import '../rule.dart';

/// No translation entry may have an empty string value. Empty strings
/// often slip through when an AI agent extracts a key it can't translate
/// and leaves the value blank as a "TODO", or when a CSV import drops a
/// row. Either way they render as visible blanks in the UI.
class EmptyValuesRule extends Rule {
  const EmptyValuesRule();

  @override
  String get name => 'empty_values';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    // Source-side empties are caught here too — an empty source string
    // is almost always a mistake (the dev forgot to fill it in).
    for (final entry in project.source.entries) {
      if (entry.value.isEmpty) {
        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message: 'Source value for key `${entry.key}` is empty.',
            key: entry.key,
            file: project.source.sourcePath,
            line: project.source.entryLines[entry.key],
            hint:
                'An empty source string renders as a blank in the UI. '
                'Fill in the canonical English string or delete the key.',
          ),
        );
      }
    }

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      final arb = entry.value;
      for (final translation in arb.entries) {
        if (translation.value.isEmpty) {
          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message:
                  'Empty translation value for key '
                  '`${translation.key}`.',
              locale: locale,
              key: translation.key,
              file: arb.sourcePath,
              line: arb.entryLines[translation.key],
              hint:
                  'Translate the key or remove the entry — an empty '
                  'string renders as a blank in the UI. `dialect translate` '
                  'can fill in missing translations.',
            ),
          );
        }
      }
    }

    return issues;
  }
}
