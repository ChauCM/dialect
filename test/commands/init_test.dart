@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:dialect/templates/dialect_yaml.dart';
import 'package:dialect/templates/gitignore_snippet.dart';
import 'package:dialect/templates/glossary_yaml.dart';
import 'package:dialect/templates/source_arb.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dialect_init_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<int> runInit(List<String> args) {
    return DialectCommandRunner()
        .run(<String>['init', ...args, tmp.path]).then((code) => code ?? 0);
  }

  group('dialect init', () {
    test('creates the dialect/ tree in an empty directory', () async {
      final code = await runInit([]);
      expect(code, 0);

      expect(File(p.join(tmp.path, 'dialect', 'dialect.yaml')).existsSync(),
          isTrue);
      expect(File(p.join(tmp.path, 'dialect', 'glossary.yaml')).existsSync(),
          isTrue);
      expect(
        File(p.join(tmp.path, 'dialect', 'source', 'en.arb')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tmp.path, 'dialect', 'translations')).existsSync(),
        isTrue,
      );
    });

    test('written files are byte-identical to the templates', () async {
      await runInit([]);
      expect(
        File(p.join(tmp.path, 'dialect', 'dialect.yaml')).readAsStringSync(),
        dialectYamlTemplate,
      );
      expect(
        File(p.join(tmp.path, 'dialect', 'glossary.yaml')).readAsStringSync(),
        glossaryYamlTemplate,
      );
      expect(
        File(p.join(tmp.path, 'dialect', 'source', 'en.arb'))
            .readAsStringSync(),
        sourceArbTemplate,
      );
    });

    test('creates .gitignore when missing', () async {
      await runInit([]);
      final gitignore = File(p.join(tmp.path, '.gitignore')).readAsStringSync();
      expect(gitignore, equals(gitignoreSnippet));
      expect(gitignore, contains('.dialect/'));
    });

    test('appends to an existing .gitignore preserving prior content',
        () async {
      File(p.join(tmp.path, '.gitignore')).writeAsStringSync('build/\n*.log\n');
      await runInit([]);
      final out = File(p.join(tmp.path, '.gitignore')).readAsStringSync();
      expect(out, startsWith('build/\n*.log\n'));
      expect(out, contains('.dialect/'));
    });

    test("does not duplicate .dialect/ if it's already in .gitignore",
        () async {
      File(p.join(tmp.path, '.gitignore'))
          .writeAsStringSync('build/\n.dialect/\n*.log\n');
      await runInit([]);
      final out = File(p.join(tmp.path, '.gitignore')).readAsStringSync();
      expect(out, 'build/\n.dialect/\n*.log\n',
          reason: 'an existing .dialect/ entry must not be duplicated');
    });

    test('refuses to overwrite an existing dialect/ without --force', () async {
      Directory(p.join(tmp.path, 'dialect')).createSync();
      File(p.join(tmp.path, 'dialect', 'sentinel'))
          .writeAsStringSync('do not delete');

      final code = await runInit([]);
      expect(code, isNot(0));
      // Sentinel must still exist after the refused init.
      expect(
        File(p.join(tmp.path, 'dialect', 'sentinel')).existsSync(),
        isTrue,
      );
    });

    test('--force overwrites an existing dialect/', () async {
      Directory(p.join(tmp.path, 'dialect')).createSync();
      File(p.join(tmp.path, 'dialect', 'stale.yaml'))
          .writeAsStringSync('stale');

      final code = await runInit(['--force']);
      expect(code, 0);
      expect(
        File(p.join(tmp.path, 'dialect', 'dialect.yaml')).existsSync(),
        isTrue,
      );
      // The stale unrelated file inside dialect/ is left alone — init only
      // writes the canonical files, it doesn't wipe the directory.
      expect(
        File(p.join(tmp.path, 'dialect', 'stale.yaml')).existsSync(),
        isTrue,
      );
    });

    test('rejects more than one positional path argument', () async {
      final code = await DialectCommandRunner()
          .run(<String>['init', tmp.path, '/another/path']).then((c) => c ?? 0);
      expect(code, 64);
    });

    test('errors when the target directory does not exist', () async {
      final code = await DialectCommandRunner().run(<String>[
        'init',
        '/no/such/path/xyz_${DateTime.now().millisecondsSinceEpoch}'
      ]).then((c) => c ?? 0);
      expect(code, 66);
    });
  });
}
