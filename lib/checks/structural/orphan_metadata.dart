import '../../arb/arb_file.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Surfaces `@key` blocks whose corresponding key/value pair is missing
/// (e.g. a `@checkout.bookNow` entry with no `checkout.bookNow` next to
/// it).
///
/// The parser preserves these in [ArbFile.orphanMetadata] rather than
/// silently dropping them, so this rule can flag them as a structural
/// error. `dialect check --fix` strips them from the written output by
/// construction — the writer never emits orphan metadata. So fixing the
/// problem is mechanical.
class OrphanMetadataRule extends Rule {
  const OrphanMetadataRule();

  @override
  String get name => 'orphan_metadata';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    void emit(String? locale, ArbFile arb, String orphanKey) {
      issues.add(
        Issue(
          severity: defaultSeverity,
          ruleName: name,
          message: '`@$orphanKey` has no matching key/value pair.',
          locale: locale,
          key: orphanKey,
          file: arb.sourcePath,
          line: arb.entryLines['@$orphanKey'],
          hint:
              'Either add a `$orphanKey` entry above this block, or '
              'delete the orphan. `dialect check --fix` removes orphans '
              'automatically.',
        ),
      );
    }

    for (final orphanKey in project.source.orphanMetadata.keys) {
      emit(null, project.source, orphanKey);
    }
    for (final entry in project.translations.entries) {
      for (final orphanKey in entry.value.orphanMetadata.keys) {
        emit(entry.key, entry.value, orphanKey);
      }
    }

    return issues;
  }
}
