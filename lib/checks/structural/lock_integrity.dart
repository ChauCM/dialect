import '../../project/dialect_project.dart';
import '../rule.dart';

/// A lock must record WHAT it approved: `@key.locked: true` is only valid
/// alongside a `source_hash` captured at lock time.
///
/// The lock's promise is "a human approved this translation of THAT source".
/// A bare boolean lock keeps the first half and loses the second — when the
/// English later changes, nothing can tell that the approval predates the
/// change, so the stale translation ships silently under a human's name.
/// With the hash, the lock holds but the entry reports locked + stale
/// (`stale_translation`), which a human clears by re-reviewing and
/// re-locking.
class LockIntegrityRule extends Rule {
  const LockIntegrityRule();

  @override
  String get name => 'lock_integrity';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    for (final entry in project.translations.entries) {
      final locale = entry.key;
      if (locale == project.config.sourceLocale) continue;
      final arb = entry.value;
      for (final t in arb.entries) {
        final meta = t.metadata;
        if (meta == null || !meta.locked) continue;
        if (meta.sourceHash != null && meta.sourceHash!.isNotEmpty) continue;
        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message:
                'Lock on `${t.key}` records no source_hash — a bare lock '
                'cannot say what it approved.',
            locale: locale,
            key: t.key,
            file: arb.sourcePath,
            line: arb.entryLines[t.key],
            hint:
                'Run `dialect lock ${t.key} --locale $locale` to re-lock it with the '
                'hash stamped (or re-lock in `dialect serve`), so later '
                'source edits surface as locked + stale instead of shipping '
                'silently.',
          ),
        );
      }
    }
    return issues;
  }
}
