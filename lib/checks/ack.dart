import '../arb/source_hash.dart';
import '../project/dialect_project.dart';
import '../state/state_store.dart';
import 'check_runner.dart';
import 'rule.dart';

/// Applies `.dialect/state.json` acknowledgements to a [CheckResult].
///
/// Per `dialect/spec/state.md`: an issue is suppressed when its stored
/// `acknowledged` fingerprint still matches the recomputed value. When the
/// fingerprint has drifted (source or translation edited since the ack),
/// the issue surfaces again and the ack is reported as **stale** so the
/// reviewer can re-ack or delete it. Only the four heuristic rules are
/// ack-able; structural rules are correctness failures and are never
/// suppressed.

/// Rules whose warnings may be acknowledged, and what each fingerprints.
/// `true` → hash the **source** value; `false` → hash the **translation**
/// value. Anything not in this map is not ack-able (structural rules).
const Map<String, bool> _ackableHashesSource = {
  'source_equality': true,
  'glossary': true,
  'untranslated_english': false,
  'length_ratio': false,
};

/// Whether [ruleName] supports acknowledgement at all.
bool isAckableRule(String ruleName) =>
    _ackableHashesSource.containsKey(ruleName);

/// Whether [ruleName] fingerprints the source value (vs. the translation
/// value). Only meaningful for ack-able rules.
bool isSourceHashed(String ruleName) => _ackableHashesSource[ruleName] ?? false;

/// The `<rule>:<locale>:<key>` identifier for an issue, or `null` if the
/// issue lacks the parts an ack needs (key is always required; a
/// source-only issue uses the literal `source` locale slot).
String? ackId(Issue issue) {
  if (issue.key == null) return null;
  final locale = issue.locale ?? 'source';
  return '${issue.ruleName}:$locale:${issue.key}';
}

/// Compute the ack fingerprint for [ruleName] on [key]/[locale] from the
/// current project state, or `null` if it can't be resolved (unknown rule,
/// missing key/translation). Used both to match acks at check-time and to
/// write a fresh ack via `dialect check --ack`.
String? ackFingerprint(
  String ruleName,
  String? locale,
  String key,
  DialectProject project,
) {
  final hashesSource = _ackableHashesSource[ruleName];
  if (hashesSource == null) return null;

  if (hashesSource) {
    final entry = project.source.entryFor(key);
    if (entry == null) return null;
    return computeSourceHash(entry.value);
  } else {
    if (locale == null) return null;
    final arb = project.translations[locale];
    final entry = arb?.entryFor(key);
    if (entry == null) return null;
    return computeSourceHash(entry.value);
  }
}

/// Result of folding acknowledgements into a check run.
class AckOutcome {
  AckOutcome({
    required this.result,
    required this.suppressed,
    required this.staleAcks,
  });

  /// Issues that survived suppression (what the report should show and
  /// what the exit code is computed from).
  final CheckResult result;

  /// How many issues a valid ack hid this run.
  final int suppressed;

  /// Ack ids that fired again because their fingerprint drifted. Sorted.
  final List<String> staleAcks;
}

/// Fold [state] into [result] for [project]. Suppresses issues whose ack
/// still matches; surfaces (does not suppress) issues whose ack is stale,
/// recording the stale ids.
AckOutcome applyAcks(
  CheckResult result,
  DialectProject project,
  StateStore state,
) {
  if (state.checks.isEmpty) {
    return AckOutcome(result: result, suppressed: 0, staleAcks: const []);
  }

  final surviving = <Issue>[];
  final staleAcks = <String>{};
  var suppressed = 0;

  for (final issue in result.issues) {
    final id = ackId(issue);
    final ack = id == null ? null : state.checks[id];
    if (ack == null || !isAckableRule(issue.ruleName)) {
      surviving.add(issue);
      continue;
    }
    final current = ackFingerprint(
      issue.ruleName,
      issue.locale,
      issue.key!,
      project,
    );
    if (current != null && current == ack.acknowledged) {
      suppressed++; // matches — hide it
    } else {
      surviving.add(issue); // drifted — show it again
      staleAcks.add(id!);
    }
  }

  return AckOutcome(
    result: CheckResult(issues: surviving),
    suppressed: suppressed,
    staleAcks: staleAcks.toList()..sort(),
  );
}
