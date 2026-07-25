import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/toolchain_version.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  /// A project declaring [floor] as its toolchain floor (or none at all).
  dynamic p({Object? toolchain}) => project(
    targetLocales: const ['vi'],
    source: arb(
      locale: 'en',
      entries: [ArbEntry(key: 'greeting', value: 'Hello')],
    ),
    extras: toolchain == null ? const {} : {'toolchain': toolchain},
  );

  List<Issue> runAt(String running, {Object? toolchain}) =>
      ToolchainVersionRule(
        runningVersion: running,
      ).run(p(toolchain: toolchain));

  group('ToolchainVersionRule', () {
    test('no toolchain block: never fires (opt-in)', () {
      expect(runAt('1.0.0'), isEmpty);
    });

    test('block without min_version is ignored', () {
      expect(runAt('1.0.0', toolchain: {'note': 'hi'}), isEmpty);
    });

    test('an older binary is an error', () {
      final issues = runAt('1.1.0', toolchain: {'min_version': '1.2.0'});
      expect(issues, hasLength(1));
      expect(issues.single.ruleName, 'toolchain_version');
      expect(issues.single.severity, IssueSeverity.error);
      expect(issues.single.message, contains('1.2.0'));
      expect(issues.single.message, contains('1.1.0'));
    });

    test('an exactly-matching binary passes', () {
      expect(runAt('1.2.0', toolchain: {'min_version': '1.2.0'}), isEmpty);
    });

    test('a newer binary passes', () {
      expect(runAt('1.3.1', toolchain: {'min_version': '1.2.0'}), isEmpty);
    });

    test('a pre-release satisfies its own release floor', () {
      // The case that matters for source builds of the current tip: strict
      // semver would order 1.2.0-dev below 1.2.0 and fail every such build.
      expect(runAt('1.2.0-dev', toolchain: {'min_version': '1.2.0'}), isEmpty);
    });

    test('a pre-release of an older release still fails', () {
      expect(
        runAt('1.1.0-dev', toolchain: {'min_version': '1.2.0'}),
        hasLength(1),
      );
    });

    test('compares numerically, not lexically', () {
      // '1.10.0' < '1.9.0' as strings; the rule must not think so.
      expect(runAt('1.10.0', toolchain: {'min_version': '1.9.0'}), isEmpty);
      expect(
        runAt('1.9.0', toolchain: {'min_version': '1.10.0'}),
        hasLength(1),
      );
    });

    test('patch-level differences are respected', () {
      expect(runAt('1.2.0', toolchain: {'min_version': '1.2.3'}), hasLength(1));
      expect(runAt('1.2.3', toolchain: {'min_version': '1.2.3'}), isEmpty);
    });

    test('a short floor like `1.2` is treated as 1.2.0', () {
      expect(runAt('1.2.0', toolchain: {'min_version': '1.2'}), isEmpty);
      expect(runAt('1.1.9', toolchain: {'min_version': '1.2'}), hasLength(1));
    });

    test('a numeric (unquoted YAML) floor works', () {
      // `min_version: 1.2` parses as a double, not a string.
      expect(runAt('1.1.0', toolchain: {'min_version': 1.2}), hasLength(1));
    });

    test('an unparseable floor stays silent rather than inventing failure', () {
      expect(runAt('1.0.0', toolchain: {'min_version': 'latest'}), isEmpty);
      expect(runAt('1.0.0', toolchain: {'min_version': '1.2.0.4'}), isEmpty);
    });

    test('a non-map toolchain value is ignored', () {
      expect(runAt('1.0.0', toolchain: '1.2.0'), isEmpty);
    });

    test('the hint offers both directions of fix', () {
      final issue = runAt('1.0.0', toolchain: {'min_version': '1.2.0'}).single;
      expect(issue.hint, contains('Upgrade'));
      expect(issue.hint, contains('min_version'));
    });
  });
}
