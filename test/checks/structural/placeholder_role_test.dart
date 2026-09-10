import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/placeholder_role.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

List<Issue> issuesFor(Map<String, ArbPlaceholder> declared) {
  final p = project(
    targetLocales: const ['vi'],
    source: arb(
      locale: 'en',
      entries: [
        ArbEntry(
          key: 'k',
          value: 'Goal {goal} opens now.',
          metadata: ArbMetadata(namespace: 'app', placeholders: declared),
        ),
      ],
    ),
  );
  return const PlaceholderRoleRule().run(p);
}

void main() {
  group('PlaceholderRoleRule', () {
    for (final role in placeholderRoles) {
      test('accepts "$role"', () {
        expect(issuesFor({'goal': ArbPlaceholder(role: role)}), isEmpty);
      });
    }

    test('a placeholder with no role is fine — it means "infer"', () {
      expect(issuesFor({'goal': ArbPlaceholder(type: 'int')}), isEmpty);
    });

    test('an entry with no placeholders at all is fine', () {
      expect(issuesFor(const {}), isEmpty);
    });

    test('a typo is an error, because nothing else would ever say so', () {
      // The author believes plural_shape is settled for this placeholder.
      // It is not: the rule falls back to inference and fires anyway.
      final issues = issuesFor({
        'goal': ArbPlaceholder(type: 'int', role: 'identifer'),
      });
      expect(issues, hasLength(1));
      expect(issues.first.severity, IssueSeverity.error);
      expect(issues.first.message, contains('identifer'));
      expect(issues.first.message, contains('being ignored'));
      expect(issues.first.hint, contains('identifier'));
    });

    test('roles are case-sensitive', () {
      expect(
        issuesFor({'goal': ArbPlaceholder(role: 'Identifier')}),
        hasLength(1),
      );
    });

    test('reports every bad placeholder in a key, not just the first', () {
      final issues = issuesFor({
        'goal': ArbPlaceholder(role: 'nope'),
        'step': ArbPlaceholder(role: 'also-nope'),
      });
      expect(issues, hasLength(2));
    });
  });
}
