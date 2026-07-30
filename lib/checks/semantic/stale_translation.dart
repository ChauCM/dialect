import '../../arb/freshness.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Flags translations whose stored `@key.source_hash` no longer matches the
/// current English source — i.e. the source changed after the translation
/// was written, so the translation is potentially out of date.
///
/// This is the change-half of the sync loop. It only fires for translations
/// that carry a `source_hash` (tracked provenance); untracked translations
/// are silent, so adopting the feature never floods an existing project.
///
/// Warning severity (soft by default; promotes under `--strict`, so CI gates
/// on it). Resolved by re-translating (`dialect translate` — which refreshes
/// the hash) or by locking the value in `dialect serve` if it's still correct
/// despite the source wording change (locking re-stamps the hash). It is not
/// `--ack`-able: staleness is a fact about provenance, not a heuristic false
/// positive — the resolution is to refresh, not to silence.
class StaleTranslationRule extends Rule {
  const StaleTranslationRule();

  @override
  String get name => 'stale_translation';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final sourceHashes = computeSourceHashes(project.source);
    final issues = <Issue>[];

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      final arb = entry.value;
      for (final e in arb.entries) {
        if (!isStaleEntry(e, sourceHashes)) continue;
        final locked = e.metadata?.locked ?? false;
        issues.add(
          Issue(
            severity: IssueSeverity.warning,
            ruleName: name,
            message:
                'Translation for `${e.key}` is stale — the English source '
                'changed since it was translated.',
            locale: locale,
            key: e.key,
            file: arb.sourcePath,
            line: arb.entryLines[e.key],
            hint: locked
                ? 'A human locked this. Unlock + re-translate, or re-lock it '
                      'against the new source in `dialect serve` if it still '
                      'reads correctly.'
                : 'If the translation is still correct as-is, run '
                      '`dialect accept ${e.key} --locale $locale` to re-bless it. '
                      'Otherwise run `dialect translate` to refresh it.',
          ),
        );
      }
    }
    return issues;
  }
}
