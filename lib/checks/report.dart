import 'dart:io';

import 'check_runner.dart';
import 'rule.dart';

/// Formats a [CheckResult] for the terminal.
///
/// Default soft-mode output gives the user concrete, actionable hints
/// alongside each finding — the "soft-mode hints must be real, not
/// stubs" promise. Format:
///
/// ```
/// dialect/translations/es.arb:42  missing_keys      Missing translation for key `checkout.bookNow`.
///                                                   hint: Run `dialect translate` to backfill missing keys.
/// ```
class CheckReport {
  CheckReport._();

  /// Print [result] to [out] (default stdout). Returns the exit code
  /// the caller should propagate.
  ///
  /// - Soft mode (`strict: false`): warnings printed, errors printed,
  ///   exit code reflects errors only.
  /// - Strict mode (`strict: true`): warnings get promoted to errors,
  ///   exit code reflects both. `length_ratio` warnings stay warnings
  ///   unless `strictLength: true` is also passed — length ratios are
  ///   noisy enough that a blanket CI gate produces too many false
  ///   positives.
  static int write(
    CheckResult result, {
    required bool strict,
    bool strictLength = false,
    IOSink? out,
  }) {
    final sink = out ?? stdout;

    final failing = result
        .failing(strict: strict, strictLength: strictLength)
        .toList();

    if (result.issues.isEmpty) {
      sink.writeln('✓ dialect check: no issues');
      return 0;
    }

    final byFile = <String, List<Issue>>{};
    final noFile = <Issue>[];
    for (final issue in result.issues) {
      if (issue.file == null) {
        noFile.add(issue);
      } else {
        (byFile[issue.file!] ??= []).add(issue);
      }
    }

    for (final file in byFile.keys.toList()..sort()) {
      for (final issue in byFile[file]!) {
        _writeIssue(sink, issue, strict: strict, strictLength: strictLength);
      }
    }
    for (final issue in noFile) {
      _writeIssue(sink, issue, strict: strict, strictLength: strictLength);
    }

    final errorCount = failing.length;
    final warningCount = result.issues
        .where((i) => i.severity == IssueSeverity.warning)
        .length;

    sink.writeln('');
    if (strict) {
      sink.writeln(
        errorCount > 0
            ? '✗ dialect check --strict: $errorCount issue(s)'
            : '✓ dialect check --strict: no issues',
      );
    } else {
      final parts = <String>[];
      if (warningCount > 0) parts.add('$warningCount warning(s)');
      final realErrors = result.issues
          .where((i) => i.severity == IssueSeverity.error)
          .length;
      if (realErrors > 0) parts.add('$realErrors error(s)');
      sink.writeln(
        realErrors > 0
            ? '✗ dialect check: ${parts.join(", ")}'
            : '! dialect check: ${parts.join(", ")} (warnings only — '
                  'exit 0 in soft mode; run with --strict in CI)',
      );
    }

    return errorCount > 0 ? 1 : 0;
  }

  static void _writeIssue(
    IOSink sink,
    Issue issue, {
    required bool strict,
    required bool strictLength,
  }) {
    final loc = issue.line != null
        ? '${issue.file}:${issue.line}'
        : issue.file ?? '<project>';
    final promoted =
        strict &&
        issue.severity == IssueSeverity.warning &&
        (issue.ruleName != 'length_ratio' || strictLength);
    final effective = (issue.severity == IssueSeverity.error || promoted)
        ? IssueSeverity.error
        : IssueSeverity.warning;
    final tag = effective == IssueSeverity.error ? '✗' : '⚠';
    sink.writeln('$tag $loc  ${issue.ruleName}  ${issue.message}');
    if (issue.hint != null) {
      sink.writeln('  hint: ${issue.hint}');
    }
  }
}
