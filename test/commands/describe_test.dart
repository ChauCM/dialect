@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect describe', () {
    test('writes .dialect/describe-plan.md with substituted tokens', () async {
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final exit = await DialectCommandRunner().run([
        'describe',
        '--path',
        'lib/',
        tmp.path,
      ]);
      expect(exit, 0);

      final plan = File(p.join(tmp.path, '.dialect', 'describe-plan.md'));
      expect(plan.existsSync(), isTrue);
      final body = plan.readAsStringSync();
      expect(body, isNot(contains('{{PATH}}')));
      expect(body, isNot(contains('{{SOURCE_LOCALE}}')));
      expect(body, isNot(contains('{{TARGET_LOCALES}}')));
      expect(body, isNot(contains('{{PROJECT_NAME}}')));
      expect(body, isNot(contains('{{GENERATED_AT}}')));
      expect(body, contains('lib/'));
      expect(body, contains('Source locale: `en`'));
      // The hard guardrail must survive substitution.
      expect(body, contains('Do not modify source code under `lib/`'));
    });

    test('omitting --path falls back to a clear placeholder', () async {
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final exit = await DialectCommandRunner().run(['describe', tmp.path]);
      expect(exit, 0);
      final body = File(
        p.join(tmp.path, '.dialect', 'describe-plan.md'),
      ).readAsStringSync();
      expect(body, contains('(the project root)'));
    });

    test('overwrites an existing plan file', () async {
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final plan = File(p.join(tmp.path, '.dialect', 'describe-plan.md'));
      plan.parent.createSync(recursive: true);
      plan.writeAsStringSync('STALE');

      final exit = await DialectCommandRunner().run([
        'describe',
        '--path',
        'lib/',
        tmp.path,
      ]);
      expect(exit, 0);
      expect(plan.readAsStringSync(), isNot(equals('STALE')));
    });

    test('exits 66 when run outside a project', () async {
      final tmp = Directory.systemTemp.createTempSync(
        'dialect_describe_no_proj_',
      );
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final exit = await DialectCommandRunner().run([
        'describe',
        '--path',
        'lib/',
        tmp.path,
      ]);
      expect(exit, 66);
    });

    test('does not read any source code file at --path', () async {
      // Same acceptance criterion as the import test: Dialect must not
      // open .dart/.kt/.swift/.cs files. Point --path at a path that
      // doesn't exist and assert success.
      final tmp = _scratchProject();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final exit = await DialectCommandRunner().run([
        'describe',
        '--path',
        'definitely/does/not/exist/',
        tmp.path,
      ]);
      expect(exit, 0);
    });
  });
}

Directory _scratchProject() {
  final tmp = Directory.systemTemp.createTempSync('dialect_describe_');
  final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
  File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [es, ja]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common]
''');
  Directory(p.join(dialectDir.path, 'source')).createSync();
  File(
    p.join(dialectDir.path, 'source', 'en.arb'),
  ).writeAsStringSync('{\n  "@@locale": "en"\n}\n');
  Directory(p.join(dialectDir.path, 'translations')).createSync();
  return tmp;
}
