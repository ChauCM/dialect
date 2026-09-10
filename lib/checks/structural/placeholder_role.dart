import '../../arb/arb_file.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// `@key.placeholders.<name>.role` must name a role Dialect knows.
///
/// `role` tells the count-aware checks what a number *means*, because `type:
/// int` cannot: "Goal {goal}" identifies, "{count} steps" counts. That makes
/// a misspelled role the worst kind of quiet failure — the author writes
/// `"identifer"`, believes `plural_shape` is settled for that placeholder,
/// and gets neither the waiver nor a word about it.
///
/// So an unrecognized role is an error, not a warning: the rules that read it
/// fall back to inference, and nothing else would ever tell the author their
/// declaration is inert. A missing `role` is fine — it means "infer".
class PlaceholderRoleRule extends Rule {
  const PlaceholderRoleRule();

  @override
  String get name => 'placeholder_role';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    final legal = (placeholderRoles.toList()..sort()).join(', ');

    for (final entry in project.source.entries) {
      final placeholders = entry.metadata?.placeholders;
      if (placeholders == null) continue;
      for (final MapEntry(key: name, value: ph) in placeholders.entries) {
        final role = ph.role;
        if (role == null || placeholderRoles.contains(role)) continue;
        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: this.name,
            message:
                'Placeholder `$name` in `${entry.key}` declares an unknown '
                'role "$role", so it is being ignored.',
            key: entry.key,
            file: project.source.sourcePath,
            line: project.source.entryLines[entry.key],
            hint:
                'Use one of: $legal. `count` is the number a plural agrees '
                'with; `identifier` labels something ("Goal 3"); `ordinal` '
                'places it in a sequence. Drop the field to let Dialect '
                'infer from the type and name.',
          ),
        );
      }
    }

    return issues;
  }
}
