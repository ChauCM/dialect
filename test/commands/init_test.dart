@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:dialect/templates/dialect_yaml.dart';
import 'package:dialect/templates/gitignore_snippet.dart';
import 'package:dialect/templates/glossary_yaml.dart';
import 'package:dialect/templates/plan_render.dart';
import 'package:dialect/templates/source_arb.dart';
import 'package:dialect/version.dart';
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
      // dialect.yaml is the one rendered scaffold file: `toolchain.
      // min_version` is stamped with the running version, so it matches the
      // template with that single token expanded — nothing else may differ.
      expect(
        File(p.join(tmp.path, 'dialect', 'dialect.yaml')).readAsStringSync(),
        renderPlanTemplate(dialectYamlTemplate, {
          'DIALECT_VERSION': dialectVersion.split(RegExp(r'[-+]')).first,
        }),
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

    test('stamps toolchain.min_version with the running release', () async {
      await runInit([]);
      final yaml = File(
        p.join(tmp.path, 'dialect', 'dialect.yaml'),
      ).readAsStringSync();
      final release = dialectVersion.split(RegExp(r'[-+]')).first;
      expect(yaml, contains('toolchain:'));
      expect(yaml, contains('min_version: $release'));
      expect(
        yaml,
        isNot(contains('{{DIALECT_VERSION}}')),
        reason: 'the token must be expanded, not shipped literally',
      );
      expect(
        yaml,
        isNot(contains('min_version: $dialectVersion-')),
        reason: 'a -dev suffix must not be stamped as the floor',
      );
    });

    test('the stamped floor passes its own check', () async {
      // The floor init writes must never fail against the binary that wrote
      // it — otherwise every fresh project starts red.
      await runInit([]);
      final code = await DialectCommandRunner().run(<String>[
        'check',
        tmp.path,
      ]);
      expect(code, 0);
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
        final dialectYaml = File(p.join(tmp.path, 'dialect', 'dialect.yaml'));
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
        renderPlanTemplate(dialectYamlTemplate, {
          'DIALECT_VERSION': dialectVersion.split(RegExp(r'[-+]')).first,
        }),
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

    test(
      'appends to an existing AGENTS.md without clobbering content',
      () async {
        File(
          p.join(tmp.path, 'AGENTS.md'),
        ).writeAsStringSync('# Agent guidance\n\nSome existing rules.\n');
        await runInit([]);
        final body = File(p.join(tmp.path, 'AGENTS.md')).readAsStringSync();
        expect(body, startsWith('# Agent guidance\n\nSome existing rules.'));
        expect(body, contains('## Localization (Dialect)'));
      },
    );

    test(
      'appends to an existing CLAUDE.md when AGENTS.md does not exist',
      () async {
        File(
          p.join(tmp.path, 'CLAUDE.md'),
        ).writeAsStringSync('# Claude guidance\n\nProject-specific rules.\n');
        await runInit([]);
        // Should append to CLAUDE.md, NOT create a new AGENTS.md.
        expect(File(p.join(tmp.path, 'AGENTS.md')).existsSync(), isFalse);
        final body = File(p.join(tmp.path, 'CLAUDE.md')).readAsStringSync();
        expect(body, startsWith('# Claude guidance'));
        expect(body, contains('## Localization (Dialect)'));
      },
    );

    test(
      'appends to AGENTS.md and leaves CLAUDE.md untouched when both exist',
      () async {
        // A real shape (stepo-mobile): AGENTS.md is a short pointer at a long
        // CLAUDE.md. The section belongs in exactly one of them, and the file
        // we don't pick must come back byte-identical — an agent-guidance file
        // is hand-written, and silently rewriting one is unforgivable.
        File(
          p.join(tmp.path, 'AGENTS.md'),
        ).writeAsStringSync('# Agent guidance\n\nRead CLAUDE.md too.\n');
        const claudeBody = '# Claude guidance\n\nProject-specific rules.\n';
        File(p.join(tmp.path, 'CLAUDE.md')).writeAsStringSync(claudeBody);

        await runInit([]);

        final agents = File(p.join(tmp.path, 'AGENTS.md')).readAsStringSync();
        expect(agents, startsWith('# Agent guidance\n\nRead CLAUDE.md too.'));
        expect(agents, contains('## Localization (Dialect)'));
        expect(
          File(p.join(tmp.path, 'CLAUDE.md')).readAsStringSync(),
          claudeBody,
          reason:
              'CLAUDE.md must not be touched when AGENTS.md took the section',
        );
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

  group('dialect init — pubspec generate flag', () {
    test('inserts `generate: true` under flutter: when missing', () async {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('''
name: stay_booking
description: A demo app.
version: 1.0.0+1

environment:
  sdk: ^3.4.0

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');
      await runInit([]);
      final body = File(p.join(tmp.path, 'pubspec.yaml')).readAsStringSync();
      expect(body, contains('flutter:\n  generate: true\n'));
      expect(body, contains('uses-material-design: true'));
    });

    test('leaves pubspec alone when generate is already set', () async {
      const original = '''
name: stay_booking
flutter:
  generate: false
  uses-material-design: true
''';
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync(original);
      await runInit([]);
      expect(
        File(p.join(tmp.path, 'pubspec.yaml')).readAsStringSync(),
        original,
        reason: 'must not override an explicit user choice',
      );
    });

    test('writes l10n.yaml and seeds the template ARB', () async {
      // `generate: true` without an existing arb-dir makes `flutter pub get`
      // fail outright, so init must own both halves of the wiring.
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync(
        'name: stay_booking\nflutter:\n  uses-material-design: true\n',
      );
      await runInit([]);

      final l10n = File(p.join(tmp.path, 'l10n.yaml'));
      expect(l10n.existsSync(), isTrue);
      expect(l10n.readAsStringSync(), contains('arb-dir: lib/l10n'));
      expect(
        l10n.readAsStringSync(),
        contains('template-arb-file: app_en.arb'),
      );

      final seeded = File(p.join(tmp.path, 'lib', 'l10n', 'app_en.arb'));
      expect(seeded.existsSync(), isTrue, reason: 'arb-dir must exist');
      expect(seeded.readAsStringSync(), sourceArbTemplate);
    });

    test('the seed is exactly what sync would write (no orphan, no diff)', () {
      // If the seed diverged from sync's output it would either trip the
      // non-destructive orphan guard or show up as a phantom first diff.
      expect(sourceArbTemplate, contains('"commonExample"'));
      expect(sourceArbTemplate, contains('"namespace": "common"'));
    });

    test('respects an existing l10n.yaml', () async {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync(
        'name: stay_booking\nflutter:\n  uses-material-design: true\n',
      );
      const custom = 'arb-dir: lib/i18n\ntemplate-arb-file: app_en.arb\n';
      File(p.join(tmp.path, 'l10n.yaml')).writeAsStringSync(custom);

      await runInit([]);

      expect(
        File(p.join(tmp.path, 'l10n.yaml')).readAsStringSync(),
        custom,
        reason: 'the project may point gen-l10n somewhere deliberate',
      );
    });

    test('l10n.yaml arb-dir follows platforms.flutter.output', () async {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync(
        'name: stay_booking\nflutter:\n  uses-material-design: true\n',
      );
      // Scaffold first, retarget the output, then re-init to wire gen-l10n.
      await runInit([]);
      File(p.join(tmp.path, 'l10n.yaml')).deleteSync();
      final cfg = File(p.join(tmp.path, 'dialect', 'dialect.yaml'));
      cfg.writeAsStringSync(
        cfg.readAsStringSync().replaceFirst(
          'output: lib/l10n/',
          'output: lib/i18n/',
        ),
      );

      await runInit([]);

      expect(
        File(p.join(tmp.path, 'l10n.yaml')).readAsStringSync(),
        contains('arb-dir: lib/i18n'),
      );
      expect(
        File(p.join(tmp.path, 'lib', 'i18n', 'app_en.arb')).existsSync(),
        isTrue,
      );
    });

    test('does not wire gen-l10n for a non-Flutter project', () async {
      // No pubspec → not Flutter → l10n.yaml would be meaningless noise.
      expect(await runInit([]), 0);
      expect(File(p.join(tmp.path, 'l10n.yaml')).existsSync(), isFalse);
    });

    test('no-ops when pubspec.yaml is absent', () async {
      // Bare directory — no Flutter project — init still succeeds.
      expect(await runInit([]), 0);
      expect(File(p.join(tmp.path, 'pubspec.yaml')).existsSync(), isFalse);
    });
  });
}
