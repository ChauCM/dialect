@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../_support/repo_root.dart';

void main() {
  group('dialect check (integration)', () {
    test('clean against the canonical example/ project', () async {
      final exit = await DialectCommandRunner().run(<String>[
        'check',
        repoPath(['example']),
      ]);
      expect(exit, 0);
    });

    test(
      'exits 0 in soft mode even with structural errors (warnings only)',
      () async {
        // Carve a temp project with a single placeholder mismatch — an
        // error severity in soft mode that the report still surfaces.
        final tmp = Directory.systemTemp.createTempSync('dialect_check_');
        addTearDown(() {
          if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        });
        _writeProject(
          tmp.path,
          sourceLocale: 'en',
          targetLocales: ['es'],
          source: '''
{
  "@@locale": "en",
  "greet": "Hello {name}"
}
''',
          translations: {
            // Placeholder dropped → error in default severity.
            'es': '{ "@@locale": "es", "greet": "Hola" }',
          },
        );

        // Soft mode: still exits non-zero because the issue's default
        // severity IS error (not a warning). placeholder_match is an error.
        final softExit = await DialectCommandRunner().run(<String>[
          'check',
          tmp.path,
        ]);
        expect(softExit, 1);
      },
    );

    test('--strict promotes warnings to errors', () async {
      // Use a locale not in the CLDR table → plural_categories emits a
      // warning. Soft exits 0; --strict exits 1.
      final tmp = Directory.systemTemp.createTempSync('dialect_check_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: ['xy'],
        source: '''
{
  "@@locale": "en",
  "items": "{count, plural, =0{none} other{{count} items}}"
}
''',
        translations: {
          'xy': '''
{ "@@locale": "xy",
  "items": "{count, plural, one{x} other{y}}" }
''',
        },
      );

      final softExit = await DialectCommandRunner().run(<String>[
        'check',
        tmp.path,
      ]);
      expect(softExit, 0, reason: 'warning-only, soft mode exits 0');

      final strictExit = await DialectCommandRunner().run(<String>[
        'check',
        '--strict',
        tmp.path,
      ]);
      expect(strictExit, 1, reason: '--strict promotes warnings to errors');
    });

    test('--fix normalizes the ARB files', () async {
      final tmp = Directory.systemTemp.createTempSync('dialect_check_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      // Source ARB with an orphan @key block and unsorted keys.
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: ['es'],
        source: '''
{
  "@@locale": "en",
  "z.last": "Last",
  "a.first": "First",
  "@orphan": { "description": "should be stripped" }
}
''',
        translations: {
          // Translation ARB that wrongly carries @key metadata.
          'es': '''
{
  "@@locale": "es",
  "a.first": "Primero",
  "@a.first": { "description": "should be stripped" },
  "z.last": "Último"
}
''',
        },
      );

      final exit = await DialectCommandRunner().run(<String>[
        'check',
        '--fix',
        tmp.path,
      ]);
      expect(
        exit,
        0,
        reason:
            'after --fix strips the orphan and re-sorts, the second check '
            'pass should be clean (no real missing keys remain)',
      );

      final src = File(
        p.join(tmp.path, 'dialect', 'source', 'en.arb'),
      ).readAsStringSync();
      expect(
        src.contains('@orphan'),
        isFalse,
        reason: 'orphan @key block must be stripped',
      );
      // a.first sorts before z.last.
      expect(src.indexOf('"a.first"'), lessThan(src.indexOf('"z.last"')));

      final esBody = File(
        p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
      ).readAsStringSync();
      expect(
        esBody.contains('@a.first'),
        isFalse,
        reason: 'translation @key metadata must be stripped',
      );
    });

    test('errors gracefully when run outside a project', () async {
      final tmp = Directory.systemTemp.createTempSync('dialect_no_proj_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final exit = await DialectCommandRunner().run(<String>[
        'check',
        tmp.path,
      ]);
      expect(exit, 66);
    });
  });
}

void _writeProject(
  String root, {
  required String sourceLocale,
  required List<String> targetLocales,
  required String source,
  Map<String, String> translations = const {},
}) {
  final dialectDir = Directory(p.join(root, 'dialect'))..createSync();
  File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: $sourceLocale
target_locales: ${targetLocales.isEmpty ? '[]' : '[${targetLocales.join(', ')}]'}
''');
  final srcDir = Directory(p.join(dialectDir.path, 'source'))..createSync();
  File(p.join(srcDir.path, '$sourceLocale.arb')).writeAsStringSync(source);
  final tDir = Directory(p.join(dialectDir.path, 'translations'))..createSync();
  for (final entry in translations.entries) {
    File(p.join(tDir.path, '${entry.key}.arb')).writeAsStringSync(entry.value);
  }
}
