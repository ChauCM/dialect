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
        .run(<String>['init', ...args, tmp.path])
        .then((code) => code ?? 0);
  }

  group('dialect init — scaffold', () {
    test('creates the dialect/ tree in an empty directory', () async {
      final code = await runInit([]);
      expect(code, 0);

      expect(
        File(p.join(tmp.path, 'dialect', 'dialect.yaml')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tmp.path, 'dialect', 'glossary.yaml')).existsSync(),
        isTrue,
      );
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
        File(
          p.join(tmp.path, 'dialect', 'source', 'en.arb'),
        ).readAsStringSync(),
        sourceArbTemplate,
      );
    });

    test('creates .gitignore when missing', () async {
      await runInit([]);
      final gitignore = File(p.join(tmp.path, '.gitignore')).readAsStringSync();
      expect(gitignore, equals(gitignoreSnippet));
      expect(gitignore, contains('.dialect/'));
    });

    test(
      'appends to an existing .gitignore preserving prior content',
      () async {
        File(
          p.join(tmp.path, '.gitignore'),
        ).writeAsStringSync('build/\n*.log\n');
        await runInit([]);
        final out = File(p.join(tmp.path, '.gitignore')).readAsStringSync();
        expect(out, startsWith('build/\n*.log\n'));
        expect(out, contains('.dialect/'));
      },
    );

    test(
      "does not duplicate .dialect/ if it's already in .gitignore",
      () async {
        File(
          p.join(tmp.path, '.gitignore'),
        ).writeAsStringSync('build/\n.dialect/\n*.log\n');
        await runInit([]);
        final out = File(p.join(tmp.path, '.gitignore')).readAsStringSync();
        expect(
          out,
          'build/\n.dialect/\n*.log\n',
          reason: 'an existing .dialect/ entry must not be duplicated',
        );
      },
    );

    test('rejects more than one positional path argument', () async {
      final code = await DialectCommandRunner()
          .run(<String>['init', tmp.path, '/another/path'])
          .then((c) => c ?? 0);
      expect(code, 64);
    });

    test('errors when the target directory does not exist', () async {
      final code = await DialectCommandRunner()
          .run(<String>[
            'init',
            '/no/such/path/xyz_${DateTime.now().millisecondsSinceEpoch}',
          ])
          .then((c) => c ?? 0);
      expect(code, 66);
    });
  });

  group('dialect init — re-run idempotency', () {
    test(
      're-running without --force preserves the scaffold and refreshes plan',
      () async {
        await runInit([]);
        // User has edited dialect.yaml; the second run must not clobber it.
        final dialectYaml = File(
          p.join(tmp.path, 'dialect', 'dialect.yaml'),
        );
        const userEdit = '# user-edited content\nsource_locale: en\n';
        dialectYaml.writeAsStringSync(userEdit);

        final code = await runInit([]);
        expect(code, 0);
        expect(
          dialectYaml.readAsStringSync(),
          userEdit,
          reason: 'idempotent re-run must not overwrite user edits',
        );
        expect(
          File(p.join(tmp.path, '.dialect', 'init-plan.md')).existsSync(),
          isTrue,
          reason: 'plan file is always (re-)written',
        );
      },
    );

    test('--force re-writes the canonical scaffold files', () async {
      await runInit([]);
      File(
        p.join(tmp.path, 'dialect', 'dialect.yaml'),
      ).writeAsStringSync('# stale');

      final code = await runInit(['--force']);
      expect(code, 0);
      expect(
        File(p.join(tmp.path, 'dialect', 'dialect.yaml')).readAsStringSync(),
        dialectYamlTemplate,
      );
    });
  });

  group('dialect init — agent playbook', () {
    test('writes .dialect/init-plan.md with substituted tokens', () async {
      await runInit([]);
      final plan = File(p.join(tmp.path, '.dialect', 'init-plan.md'));
      expect(plan.existsSync(), isTrue);
      final body = plan.readAsStringSync();
      expect(body, isNot(contains('{{PROJECT_TYPE}}')));
      expect(body, isNot(contains('{{SOURCE_LOCALE}}')));
      expect(body, isNot(contains('{{TARGET_LOCALES}}')));
      expect(body, isNot(contains('{{GENERATED_AT}}')));
      // Two-phase shape is the design contract.
      expect(body, contains('## Phase 1 — Setup'));
      expect(body, contains('## Phase 2 — Extract + translate'));
      // 50-key threshold is the locked Phase-2 sizing rule.
      expect(body, contains('50 strings'));
    });

    test('creates AGENTS.md by default with the Dialect section', () async {
      await runInit([]);
      final agents = File(p.join(tmp.path, 'AGENTS.md'));
      expect(agents.existsSync(), isTrue);
      final body = agents.readAsStringSync();
      expect(body, contains('## Localization (Dialect)'));
      expect(body, contains('dialect/dialect.yaml'));
    });

    test('appends to an existing AGENTS.md without clobbering content',
        () async {
      File(p.join(tmp.path, 'AGENTS.md')).writeAsStringSync(
        '# Agent guidance\n\nSome existing rules.\n',
      );
      await runInit([]);
      final body = File(p.join(tmp.path, 'AGENTS.md')).readAsStringSync();
      expect(body, startsWith('# Agent guidance\n\nSome existing rules.'));
      expect(body, contains('## Localization (Dialect)'));
    });

    test(
      'appends to an existing CLAUDE.md when AGENTS.md does not exist',
      () async {
        File(p.join(tmp.path, 'CLAUDE.md')).writeAsStringSync(
          '# Claude guidance\n\nProject-specific rules.\n',
        );
        await runInit([]);
        // Should append to CLAUDE.md, NOT create a new AGENTS.md.
        expect(File(p.join(tmp.path, 'AGENTS.md')).existsSync(), isFalse);
        final body = File(p.join(tmp.path, 'CLAUDE.md')).readAsStringSync();
        expect(body, startsWith('# Claude guidance'));
        expect(body, contains('## Localization (Dialect)'));
      },
    );

    test('does not duplicate the section on re-run', () async {
      await runInit([]);
      await runInit([]);
      final body = File(p.join(tmp.path, 'AGENTS.md')).readAsStringSync();
      final occurrences = '## Localization (Dialect)'.allMatches(body).length;
      expect(occurrences, 1);
    });
  });
}
