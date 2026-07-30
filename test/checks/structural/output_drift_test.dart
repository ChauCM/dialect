@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/checks/check_runner.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/project/dialect_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('output_drift', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('dialect_drift_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    /// A project with one platform, and an `outputExtra` key written straight
    /// into the generated file — the state `sync` refuses on.
    void seed({String outputExtra = ''}) {
      final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [vi]
platforms:
  flutter:
    output: lib/l10n/
    format: arb
''');
      Directory(p.join(dialectDir.path, 'source')).createSync();
      File(p.join(dialectDir.path, 'source', 'en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "keep": "Keep",
  "@keep": { "namespace": "common", "description": "Keep it." }
}
''');
      Directory(p.join(dialectDir.path, 'translations')).createSync();
      File(
        p.join(dialectDir.path, 'translations', 'vi.arb'),
      ).writeAsStringSync('{ "@@locale": "vi", "keep": "Giữ" }');

      Directory(p.join(tmp.path, 'lib', 'l10n')).createSync(recursive: true);
      File(p.join(tmp.path, 'lib', 'l10n', 'app_en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "keep": "Keep"$outputExtra
}
''');
    }

    List<Issue> drift() => runChecks(
      DialectProject.load(tmp.path),
    ).issues.where((i) => i.ruleName == 'output_drift').toList();

    test('is silent when the output matches the source', () async {
      seed();
      expect(drift(), isEmpty);
    });

    test('warns when the output carries a key the source does not', () async {
      // The whole point: `check` is the prescribed FIRST command, and it used
      // to report clean on a repo where `sync` was already guaranteed to
      // refuse. The condition was knowable at minute zero and surfaced at
      // minute thirty.
      seed(outputExtra: ',\n  "addedByHand": "Straight into the output"');

      final issues = drift();
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('addedByHand'));
      expect(issues.single.message, contains('sync'));
      expect(issues.single.hint, contains('--adopt'));
      expect(issues.single.hint, contains('--prune'));
    });

    test('is a warning, so soft mode still exits 0', () async {
      // Orphans are strings in the wrong file, not wrong translations —
      // everything still builds. `--strict` is what promotes this, which is
      // where a pipeline that regenerates outputs wants to meet it.
      seed(outputExtra: ',\n  "addedByHand": "Straight into the output"');
      expect(drift().single.severity, IssueSeverity.warning);

      final result = runChecks(DialectProject.load(tmp.path));
      expect(
        result.failing(strict: false, strictLength: false),
        isEmpty,
        reason: 'soft mode reports it without failing',
      );
      expect(
        result
            .failing(strict: true, strictLength: false)
            .where((i) => i.ruleName == 'output_drift'),
        isNotEmpty,
        reason: '--strict is the CI gate',
      );
    });

    test('reports once for the project, not once per key', () async {
      seed(
        outputExtra: ',\n  "one": "One",\n  "two": "Two",\n  "three": "Three"',
      );

      final issues = drift();
      expect(issues, hasLength(1));
      expect(issues.single.message, startsWith('3 key(s)'));
    });

    test('says nothing when no platform is configured', () async {
      seed();
      File(
        p.join(tmp.path, 'dialect', 'dialect.yaml'),
      ).writeAsStringSync('source_locale: en\ntarget_locales: [vi]\n');
      expect(drift(), isEmpty);
    });
  });
}
