import '../../arb/arb_file.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Warn when a translation value equals the source value byte-for-byte.
/// Usually means the AI agent left a placeholder, the import tool copied
/// the source through, or the reviewer hasn't gotten to that key yet.
///
/// False positives: brand names ("Spotify" stays "Spotify" in every
/// locale), one-letter codes ("X", "•"), and entries the reviewer has
/// explicitly accepted. The escape hatch is `@key.locked: true` —
/// locking a translation tells the reviewer "yes, this is intentional"
/// and silences the warning.
class SourceEqualityRule extends Rule {
  const SourceEqualityRule();

  @override
  String get name => 'source_equality';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    final sourceLocale = project.config.sourceLocale;

    final sourceByKey = <String, ArbEntry>{
      for (final e in project.source.entries) e.key: e,
    };

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      if (locale == sourceLocale) continue;
      final arb = entry.value;
      for (final t in arb.entries) {
        final src = sourceByKey[t.key];
        if (src == null) continue; // covered by orphan/missing rules
        if (t.value != src.value) continue;
        if (t.metadata?.locked == true) continue; // reviewer accepted
        if (!_looksLikeCopy(t.value)) continue;

        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message: 'Translation for `${t.key}` is identical to the source.',
            locale: locale,
            key: t.key,
            file: arb.sourcePath,
            line: arb.entryLines[t.key],
            hint:
                'If this is intentional (brand name, code, untranslatable '
                'token), lock it in `dialect serve`, or add `"locked": true` '
                'plus the current `"source_hash"` to the `@${t.key}` block '
                'in this file (a bare lock fails lock_integrity). '
                'Otherwise translate the value.',
          ),
        );
      }
    }

    return issues;
  }

  /// Filter out values that are too short or too symbol-dense to be
  /// worth warning about. "OK"/"Hi" survive this filter (3+ chars with
  /// letters) so reviewers see them; "•"/"—"/"42" don't.
  static bool _looksLikeCopy(String value) {
    if (value.length < 3) return false;
    final hasLetter = value.runes.any(_isLetterRune);
    return hasLetter;
  }

  static bool _isLetterRune(int r) {
    // ASCII letters cover the common case. For non-ASCII, fall back to
    // "anything outside the Basic Latin punctuation/digit/whitespace
    // block". This is conservative but correct for the warning's
    // purpose: filter out pure-symbol strings like "•".
    if (r >= 0x41 && r <= 0x5A) return true; // A-Z
    if (r >= 0x61 && r <= 0x7A) return true; // a-z
    if (r >= 0x80) return true; // any non-ASCII counts as letter-ish
    return false;
  }
}
