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
/// reviewer can re-ack or delete it. Only the heuristic rules are ack-able;
/// structural rules are correctness failures and are never suppressed.

/// Which value a rule's ack is fingerprinted against.
///
/// The fingerprint decides when a waiver expires, so it has to name the text
/// the reviewer actually looked at. A `glossary` warning is a judgement about
/// the English; a `width_budget` warning is a judgement about the
/// translation; a `banned_pattern` warning is a judgement about whichever
/// side the banned text appeared on, since that rule scans both.
enum AckSubject { source, translation, sideOfIssue }

/// Rules whose warnings may be acknowledged, and what each fingerprints.
/// Anything not in this map is not ack-able (structural rules).
const Map<String, AckSubject> _ackSubjects = {
  'source_equality': AckSubject.source,
  'glossary': AckSubject.source,
  'plural_shape': AckSubject.source,
  'untranslated_english': AckSubject.translation,
  'length_ratio': AckSubject.translation,
  'width_budget': AckSubject.translation,
  'banned_pattern': AckSubject.sideOfIssue,
};

/// Whether [ruleName] supports acknowledgement at all.
bool isAckableRule(String ruleName) => _ackSubjects.containsKey(ruleName);

/// Every ack-able rule name, sorted — so the error text that lists them
/// cannot drift from the map itself.
List<String> get ackableRuleNames => _ackSubjects.keys.toList()..sort();

/// Whether [ruleName] fingerprints the source value (vs. the translation
/// value) for an ack in [locale]. Only meaningful for ack-able rules; drives
/// the sentence `dialect check --ack` prints back.
bool isSourceHashed(String ruleName, {String? locale}) {
  switch (_ackSubjects[ruleName]) {
    case AckSubject.source:
      return true;
    case AckSubject.sideOfIssue:
      return locale == null || locale == 'source';
    case AckSubject.translation:
    case null:
      return false;
  }
}

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
  if (!isAckableRule(ruleName)) return null;

  if (isSourceHashed(ruleName, locale: locale)) {
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

/// What a stored acknowledgement is currently worth.
///
/// [applyAcks] can only ever describe an ack whose issue **fired again** —
/// it walks the issue list, so an ack whose warning has stopped appearing is
/// unreachable from there. That is the common case in a long-lived ledger and
/// the one nobody sees: the copy gets rewritten, the fingerprint stops
/// matching, the rule stops firing, and the entry sits there reading exactly
/// like a live ruling. This enum exists so the audit can name that rung
/// instead of leaving it as the gap between "suppressed" and "stale".
enum AckStatus {
  /// Fingerprint matches and it hid a warning this run. Load-bearing.
  live,

  /// Fingerprint matches, but nothing fired for it this run — the rule
  /// narrowed, or the warning's cause moved. The ruling is still true of the
  /// text it was made about, so it is kept, not pruned.
  inert,

  /// The value was edited after the ack was made, so the adjudication is
  /// about text that no longer exists. Nobody made this ruling about what is
  /// there now.
  lapsed,

  /// The key (or its translation) is gone from the ARB entirely.
  orphaned,

  /// The id does not parse, or names a rule that cannot be acked — a hand
  /// edit or a rule that was removed since.
  invalid,
}

/// One stored ack, classified.
class AckAudit {
  AckAudit({required this.id, required this.status, required this.record});

  final String id;
  final AckStatus status;
  final AckRecord record;

  /// Whether `--prune-acks` deletes this entry.
  ///
  /// [AckStatus.inert] is deliberately kept: its fingerprint still matches,
  /// so it is a valid ruling about the current text that simply is not needed
  /// today. Deleting it would throw away a judgement someone actually made.
  bool get isDead =>
      status == AckStatus.lapsed ||
      status == AckStatus.orphaned ||
      status == AckStatus.invalid;
}

/// Classify every entry in [state] against [project], using the **raw**
/// (pre-suppression) [result] to tell a live ack from an inert one.
///
/// Sorted by id, so the output is stable in a diff.
List<AckAudit> auditAcks(
  CheckResult result,
  DialectProject project,
  StateStore state,
) {
  final fired = <String>{};
  for (final issue in result.issues) {
    final id = ackId(issue);
    if (id != null) fired.add(id);
  }

  final audits = <AckAudit>[];
  for (final entry in state.checks.entries) {
    final id = entry.key;
    final parts = id.split(':');
    if (parts.length != 3 ||
        parts.any((p) => p.isEmpty) ||
        !isAckableRule(parts[0])) {
      audits.add(
        AckAudit(id: id, status: AckStatus.invalid, record: entry.value),
      );
      continue;
    }
    final locale = parts[1] == 'source' ? null : parts[1];
    final current = ackFingerprint(parts[0], locale, parts[2], project);
    final AckStatus status;
    if (current == null) {
      status = AckStatus.orphaned;
    } else if (current != entry.value.acknowledged) {
      status = AckStatus.lapsed;
    } else if (fired.contains(id)) {
      status = AckStatus.live;
    } else {
      status = AckStatus.inert;
    }
    audits.add(AckAudit(id: id, status: status, record: entry.value));
  }

  audits.sort((a, b) => a.id.compareTo(b.id));
  return audits;
}
