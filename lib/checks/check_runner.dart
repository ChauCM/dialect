import '../project/dialect_project.dart';
import 'rule.dart';
import 'semantic/glossary.dart';
import 'semantic/length_ratio.dart';
import 'semantic/source_equality.dart';
import 'semantic/stale_translation.dart';
import 'semantic/untranslated_english.dart';
import 'semantic/width_budget.dart';
import 'structural/empty_values.dart';
import 'structural/key_format.dart';
import 'structural/lock_integrity.dart';
import 'structural/missing_keys.dart';
import 'structural/namespace_required.dart';
import 'structural/orphan_metadata.dart';
import 'structural/output_drift.dart';
import 'structural/placeholder_match.dart';
import 'structural/plural_categories.dart';
import 'structural/tag_balance.dart';
import 'structural/toolchain_version.dart';

/// The set of [Rule]s `dialect check` runs.
///
/// Structural rules live here; M8 semantic rules will be added to
/// [semanticRules] in `lib/checks/semantic/`. The runner walks both
/// lists indistinguishably — the split is for readability, not behavior.
const List<Rule> structuralRules = [
  // First: if the binary is too old to be trusted with this project, that
  // outranks anything it might report about the content.
  ToolchainVersionRule(),
  KeyFormatRule(),
  NamespaceRequiredRule(),
  MissingKeysRule(),
  PlaceholderMatchRule(),
  PluralCategoriesRule(),
  TagBalanceRule(),
  EmptyValuesRule(),
  OrphanMetadataRule(),
  LockIntegrityRule(),
  // Last of the structural set: it reports on the generated outputs rather
  // than on the canonical files, and it answers "can sync run?" rather than
  // "is this content correct?".
  OutputDriftRule(),
];

/// Semantic rules (M8). Order shapes report grouping when two rules
/// hit the same entry — structural-first, then semantic, so the user
/// sees "your placeholder is broken" before "your translation looks
/// untranslated."
const List<Rule> semanticRules = <Rule>[
  SourceEqualityRule(),
  LengthRatioRule(),
  WidthBudgetRule(),
  UntranslatedEnglishRule(),
  GlossaryRule(),
  StaleTranslationRule(),
];

/// Length-family heuristics that plain `--strict` does NOT promote to
/// errors — they need the explicit `--strict-length` opt-in.
///
/// Both are soft conventions, not hard gates: `length_ratio` is noisy, and
/// `width_budget` is a nudge to tighten a slightly-too-long label, not a
/// reason to fail CI. The report formatter reads this same set so the
/// display tag matches the exit-code logic.
const Set<String> strictLengthGatedRules = {'length_ratio', 'width_budget'};

class CheckResult {
  CheckResult({required this.issues});

  /// Every issue produced by every rule, flat. Report formatting groups
  /// these as it sees fit.
  final List<Issue> issues;

  /// Issues that map to a non-zero exit code under [strict].
  ///
  /// The length-family warnings ([strictLengthGatedRules]) are special:
  /// `--strict` alone doesn't promote them (they're heuristic/soft
  /// conventions). `--strict-length` is the explicit opt-in. The check
  /// command passes the flags through; the report formatter mirrors this
  /// so the display tag matches the exit-code logic.
  Iterable<Issue> failing({
    required bool strict,
    required bool strictLength,
  }) sync* {
    for (final issue in issues) {
      if (issue.severity == IssueSeverity.error) {
        yield issue;
      } else if (strict && _promotedUnderStrict(issue, strictLength)) {
        yield issue;
      }
    }
  }

  static bool _promotedUnderStrict(Issue issue, bool strictLength) {
    if (strictLengthGatedRules.contains(issue.ruleName)) return strictLength;
    return true;
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
