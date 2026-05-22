@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect import', () {
    test('writes .dialect/import-plan.md with substituted tokens', () async {
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final exit = await DialectCommandRunner().run([
        'import',
        '--from',
        'arb',
        '--path',
        'lib/l10n/',
        tmp.path,
      ]);
      expect(exit, 0);

      final plan = File(p.join(tmp.path, '.dialect', 'import-plan.md'));
      expect(plan.existsSync(), isTrue);
      final body = plan.readAsStringSync();
      // Tokens replaced.
      expect(body, isNot(contains('{{FROM}}')));
      expect(body, isNot(contains('{{PATH}}')));
      expect(body, isNot(contains('{{SOURCE_LOCALE}}')));
      expect(body, isNot(contains('{{TARGET_LOCALES}}')));
      expect(body, isNot(contains('{{PROJECT_NAME}}')));
      expect(body, isNot(contains('{{NAMESPACES}}')));
      expect(body, isNot(contains('{{GENERATED_AT}}')));
      // Values present.
      expect(body, contains('lib/l10n/')); // PATH
      expect(body, contains('`arb`')); // FROM
      expect(body, contains('Source locale: `en`'));
      // Anti-goal guardrail is in the plan verbatim.
      expect(body, contains('You may **read** them to derive descriptions'));
    });

    test('overwrites an existing plan file', () async {
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      // Pre-seed a stale plan.
      final plan = File(p.join(tmp.path, '.dialect', 'import-plan.md'));
      plan.parent.createSync(recursive: true);
      plan.writeAsStringSync('STALE');

      final exit = await DialectCommandRunner().run([
        'import',
        '--from',
        'arb',
        '--path',
        'lib/l10n/',
        tmp.path,
      ]);
      expect(exit, 0);
      expect(plan.readAsStringSync(), isNot(equals('STALE')));
    });

    test('exits 64 when --path is missing', () async {
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final exit = await DialectCommandRunner().run([
        'import',
        '--from',
        'arb',
        tmp.path,
      ]);
      expect(exit, 64);
      // Plan must not be written.
      expect(
        File(p.join(tmp.path, '.dialect', 'import-plan.md')).existsSync(),
        isFalse,
      );
    });

    test('exits 66 when run outside a project', () async {
      final tmp = Directory.systemTemp.createTempSync(
        'dialect_import_no_proj_',
      );
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final exit = await DialectCommandRunner().run([
        'import',
        '--from',
        'arb',
        '--path',
        'lib/l10n/',
        tmp.path,
      ]);
      expect(exit, 66);
    });

    test('does not read any source code file at --path', () async {
      // Acceptance criterion from CLAUDE.md §3.1 / §6:
      // Dialect itself never opens .dart/.kt/.swift/.cs files.
      // We test this by pointing --path at a path that DOES NOT EXIST.
      // The command must still succeed (it's writing a plan file, not
      // touching --path) — that proves Dialect never tried to read it.
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final exit = await DialectCommandRunner().run([
        'import',
        '--from',
        'arb',
        '--path',
        'definitely/does/not/exist/',
        tmp.path,
      ]);
      expect(exit, 0);
      final body = File(
        p.join(tmp.path, '.dialect', 'import-plan.md'),
      ).readAsStringSync();
      expect(body, contains('definitely/does/not/exist/'));
    });
  });
}

/// Build a temp directory with the minimum a [DialectProject] needs to
/// load: `dialect/dialect.yaml` + `dialect/source/en.arb` +
/// `dialect/translations/`. Mirrors the seed templates so this lives
/// or dies with `dialect init`.
Directory _scratchProject() {
  final tmp = Directory.systemTemp.createTempSync('dialect_import_');
  final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
  File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [es, ja]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common, checkout]

project:
  name: Demo
''');
  Directory(p.join(dialectDir.path, 'source')).createSync();
  File(
    p.join(dialectDir.path, 'source', 'en.arb'),
  ).writeAsStringSync('{\n  "@@locale": "en"\n}\n');
  Directory(p.join(dialectDir.path, 'translations')).createSync();
  return tmp;
}
