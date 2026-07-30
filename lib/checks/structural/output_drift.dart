import 'package:path/path.dart' as p;

import '../../project/dialect_project.dart';
import '../../project/output_scan.dart';
import '../rule.dart';

/// A generated output holds keys the source does not — so the very next
/// `dialect sync` will refuse.
///
/// `check` used to read `dialect/source` + `dialect/translations` and nothing
/// else, which made this condition invisible to it. The cost is an ordering
/// trap: the prescribed workflow is `check --fix → sync → check`, so a repo
/// carrying orphans reports **clean** through the first command, through every
/// edit made after it, and only refuses at the last step — on a condition that
/// was already true before any of that work started. Nothing has to be redone,
/// but half an hour passes between "knowable" and "known", and an agent will
/// not invent a `sync --dry-run` preflight for a failure mode it has not met.
///
/// So `check` now answers the question it is asked first: is this repo in a
/// state where sync can run?
///
/// It is a **warning**, not an error. Orphans are not incorrect translations —
/// they are strings living in the wrong file, and everything still builds. But
/// `--strict` promotes it, which is right for CI: a pipeline that regenerates
/// outputs must not meet this for the first time mid-run.
///
/// The fix is never automatic. `--fix` normalizes ARB shape; deciding whether
/// a hand-added key should be recovered (`sync --adopt`) or discarded
/// (`sync --prune`) is a data-loss decision that belongs to a person.
class OutputDriftRule extends Rule {
  const OutputDriftRule();

  @override
  String get name => 'output_drift';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    if (project.config.platforms.isEmpty) return const [];

    final scan = OutputScan.run(project);
    if (scan.isEmpty) return const [];

    final keys = scan.keys.toList()..sort();
    final preview = keys.length > 5
        ? '${keys.take(5).join(", ")}, … (${keys.length - 5} more)'
        : keys.join(', ');

    // One issue for the project, not one per key: the condition is "these
    // outputs and this source disagree", and the remedy is a single command
    // regardless of how many keys are involved.
    final files = <String>{
      for (final k in keys) ...scan.filesFor(k),
    }.map((f) => p.relative(f, from: project.root)).toList()..sort();

    return [
      Issue(
        severity: defaultSeverity,
        ruleName: name,
        message:
            '${keys.length} key(s) exist in a generated output but not in the '
            'source, so `dialect sync` will refuse until this is resolved: '
            '$preview  (in ${files.join(', ')})',
        hint:
            'They were almost certainly added straight to a generated file. '
            'Run `dialect sync --adopt` to pull them back into '
            'dialect/source/${project.config.sourceLocale}.arb, or '
            '`dialect sync --prune` to confirm dropping them.',
      ),
    ];
  }
}
