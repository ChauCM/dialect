import '../project/dialect_project.dart';
import 'rule.dart';
import 'structural/empty_values.dart';
import 'structural/missing_keys.dart';
import 'structural/orphan_metadata.dart';
import 'structural/placeholder_match.dart';
import 'structural/plural_categories.dart';

/// The set of [Rule]s `dialect check` runs.
///
/// Structural rules live here; M8 semantic rules will be added to
/// [semanticRules] in `lib/checks/semantic/`. The runner walks both
/// lists indistinguishably — the split is for readability, not behavior.
const List<Rule> structuralRules = [
  MissingKeysRule(),
  PlaceholderMatchRule(),
  PluralCategoriesRule(),
  EmptyValuesRule(),
  OrphanMetadataRule(),
];

/// M8 will populate this list. Empty in M4 so M4's check command has
/// the same shape as M8's.
const List<Rule> semanticRules = <Rule>[];

class CheckResult {
  CheckResult({required this.issues});

  /// Every issue produced by every rule, flat. Report formatting groups
  /// these as it sees fit.
  final List<Issue> issues;

  /// Issues that map to a non-zero exit code under [strict].
  Iterable<Issue> failing({required bool strict}) sync* {
    for (final issue in issues) {
      if (issue.severity == IssueSeverity.error) {
        yield issue;
      } else if (strict) {
        yield issue;
      }
    }
  }
}

CheckResult runChecks(
  DialectProject project, {
  List<Rule> rules = const [...structuralRules, ...semanticRules],
}) {
  final all = <Issue>[];
  for (final rule in rules) {
    all.addAll(rule.run(project));
  }
  return CheckResult(issues: all);
}
