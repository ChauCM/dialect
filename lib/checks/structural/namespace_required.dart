import '../../project/dialect_project.dart';
import '../rule.dart';

/// Every key in the SOURCE ARB must declare `@key.namespace` in its
/// metadata block. The namespace controls which keys sync to which
/// platform (the `platforms.<p>.namespaces` allowlist) and how
/// cross-platform adapters group output.
///
/// Translations don't carry @key metadata, so this rule is source-only.
class NamespaceRequiredRule extends Rule {
  const NamespaceRequiredRule();

  @override
  String get name => 'namespace_required';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    for (final entry in project.source.entries) {
      final ns = entry.metadata?.namespace;
      if (ns != null && ns.isNotEmpty) continue;
      issues.add(
        Issue(
          severity: defaultSeverity,
          ruleName: name,
          message:
              'Source key `${entry.key}` is missing `@key.namespace` '
              'metadata.',
          key: entry.key,
          file: project.source.sourcePath,
          line: project.source.entryLines[entry.key],
          hint:
              'Add `"namespace": "<group>"` to the `@${entry.key}` block. '
              'The namespace drives per-platform sync filtering.',
        ),
      );
    }

    return issues;
  }
}
