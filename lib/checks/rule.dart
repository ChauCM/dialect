import '../project/dialect_project.dart';

/// Severity of a check finding. Determines exit code and prefix in the
/// console report.
///
/// Soft mode (default): warnings stay warnings, errors are real errors,
/// exit code reflects errors only.
/// `--strict` (CI): warnings get promoted to errors before exit-code is
/// computed, except length-ratio which stays a warning unless
/// `--strict-length` is also passed.
enum IssueSeverity { warning, error }

/// A single check finding. The report formatter turns these into
/// `path/to/file.arb:42  rule_name  message` lines plus an indented
/// `hint:` line when one is set.
class Issue {
  Issue({
    required this.severity,
    required this.ruleName,
    required this.message,
    this.locale,
    this.key,
    this.file,
    this.line,
    this.hint,
  });

  /// `warning` or `error`. May be promoted by `--strict`.
  final IssueSeverity severity;

  /// Stable identifier the report uses to group issues, and that users
  /// will reference when filing bugs. Snake_case, e.g. `missing_keys`,
  /// `plural_categories`.
  final String ruleName;

  /// One-line problem description. Should be specific enough that a
  /// reader can act on it without reading the surrounding context.
  final String message;

  /// Target locale this issue applies to (e.g. `es`, `ar`). `null` for
  /// source-only issues (orphan metadata, source-ARB-level problems).
  final String? locale;

  /// Key the issue is about, if any.
  final String? key;

  /// Absolute or repo-relative path to the file containing the issue.
  /// `null` only when the rule is reporting a project-wide condition.
  final String? file;

  /// 1-based line number of the issue. Resolved from
  /// `ArbFile.entryLines` populated by the parser.
  final int? line;

  /// Concrete remediation suggestion. Real prose, not a stub — this is
  /// the "soft-mode hints must be real" promise. Examples:
  ///   "Run `dialect describe` to backfill missing descriptions."
  ///   "Preserve placeholder names byte-identically across translations."
  /// Optional; some rules don't need one.
  final String? hint;
}

/// One structural or semantic check.
///
/// M4 ships structural rules under `lib/checks/structural/`; M8 plugs in
/// semantic rules under `lib/checks/semantic/` against the same
/// interface, so the runner doesn't grow new code for either.
abstract class Rule {
  const Rule();

  /// Stable rule identifier (snake_case). Used by the report formatter
  /// to group findings and by users to silence/ack via state file
  /// (post-v1.0).
  String get name;

  /// Default severity. May be overridden per-issue.
  IssueSeverity get defaultSeverity;

  /// Inspect [project] and return findings. May return an empty list.
  /// Should NOT throw — turn unexpected conditions into Issues so the
  /// report surfaces them rather than crashing.
  List<Issue> run(DialectProject project);
}
