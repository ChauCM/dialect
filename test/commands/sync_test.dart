@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect sync (integration)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('dialect_sync_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<int> runSync([List<String> extraArgs = const []]) async {
      final code = await DialectCommandRunner().run(<String>[
        'sync',
        ...extraArgs,
        tmp.path,
      ]);
      return code ?? 0;
    }

    test('writes app_<locale>.arb files per the Flutter convention', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: ['es', 'ja'],
        source:
            '{ "@@locale": "en", "common.cancel": "Cancel", "@common.cancel": { "description": "Cancel." } }',
        translations: {
          'es': '{ "@@locale": "es", "common.cancel": "Cancelar" }',
          'ja': '{ "@@locale": "ja", "common.cancel": "キャンセル" }',
        },
        platforms: {
          'flutter': {
            'output': 'lib/l10n/',
            'format': 'arb',
            'namespaces': ['common'],
          },
        },
      );

      expect(await runSync(), 0);

      final outDir = Directory(p.join(tmp.path, 'lib', 'l10n'));
      expect(outDir.existsSync(), isTrue);
      for (final loc in ['en', 'es', 'ja']) {
        expect(
          File(p.join(outDir.path, 'app_$loc.arb')).existsSync(),
          isTrue,
          reason: 'app_$loc.arb missing',
        );
      }
    });

    test('source output keeps @key metadata; translations strip it', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: ['es'],
        source: '''
{
  "@@locale": "en",
  "common.cancel": "Cancel",
  "@common.cancel": { "description": "Cancel action label." }
}
''',
        translations: {
          'es': '{ "@@locale": "es", "common.cancel": "Cancelar" }',
        },
        platforms: {
          'flutter': {'output': 'lib/l10n/', 'format': 'arb'},
        },
      );
      await runSync();

      final src = File(
        p.join(tmp.path, 'lib', 'l10n', 'app_en.arb'),
      ).readAsStringSync();
      expect(
        src,
        contains('"@common.cancel"'),
        reason: 'source output keeps metadata',
      );

      final es = File(
        p.join(tmp.path, 'lib', 'l10n', 'app_es.arb'),
      ).readAsStringSync();
      expect(
        es,
        isNot(contains('@common.cancel')),
        reason: 'translation output is metadata-free',
      );
    });

    test('idempotent: a second sync writes nothing', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: ['es'],
        source: '{ "@@locale": "en", "k": "v" }',
        translations: {'es': '{ "@@locale": "es", "k": "v-es" }'},
        platforms: {
          'flutter': {'output': 'lib/l10n/', 'format': 'arb'},
        },
      );
      await runSync();
      final mtimes = _outputMtimes(tmp.path);

      // Sleep one millisecond to ensure mtime resolution doesn't lie.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await runSync();
      expect(
        _outputMtimes(tmp.path),
        mtimes,
        reason: 'unchanged outputs must not be rewritten',
      );
    });

    test('sync does not modify input ARBs', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: ['es'],
        source: '{ "@@locale": "en", "k": "v" }',
        translations: {'es': '{ "@@locale": "es", "k": "v-es" }'},
        platforms: {
          'flutter': {'output': 'lib/l10n/', 'format': 'arb'},
        },
      );
      final beforeSource = File(
        p.join(tmp.path, 'dialect', 'source', 'en.arb'),
      ).readAsStringSync();
      final beforeEs = File(
        p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
      ).readAsStringSync();

      await runSync();

      expect(
        File(
          p.join(tmp.path, 'dialect', 'source', 'en.arb'),
        ).readAsStringSync(),
        beforeSource,
        reason: 'sync must not auto-fix the source ARB',
      );
      expect(
        File(
          p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
        ).readAsStringSync(),
        beforeEs,
        reason: 'sync must not auto-fix translation ARBs',
      );
    });

    test(
      'resolves output paths relative to the project root, not cwd',
      () async {
        _writeProject(
          tmp.path,
          sourceLocale: 'en',
          targetLocales: const [],
          source: '{ "@@locale": "en", "k": "v" }',
          platforms: {
            'flutter': {'output': 'lib/l10n/', 'format': 'arb'},
          },
        );
        // We run from a totally unrelated working directory; the output
        // must still land inside <tmp>/lib/l10n/.
        final origCwd = Directory.current;
        Directory.current = Directory.systemTemp;
        addTearDown(() => Directory.current = origCwd);

        expect(await runSync(), 0);

        expect(
          File(p.join(tmp.path, 'lib', 'l10n', 'app_en.arb')).existsSync(),
          isTrue,
        );
      },
    );

    test('skips non-`arb` formats with a v1.1 hint', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: const [],
        source: '{ "@@locale": "en", "k": "v" }',
        platforms: {
          'ios': {'output': 'ios/', 'format': 'apple-strings'},
        },
      );
      expect(await runSync(), 0);
      // No apple-strings adapter ships in v1.0 → no file output for ios.
      expect(Directory(p.join(tmp.path, 'ios')).existsSync(), isFalse);
    });

    test('warns when no platforms are configured', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: const [],
        source: '{ "@@locale": "en", "k": "v" }',
        // No platforms block at all.
      );
      expect(await runSync(), 0);
    });
  });
}

Map<String, DateTime> _outputMtimes(String root) {
  final outDir = Directory(p.join(root, 'lib', 'l10n'));
  if (!outDir.existsSync()) return {};
  return {
    for (final entity in outDir.listSync().whereType<File>())
      p.basename(entity.path): entity.lastModifiedSync(),
  };
}

void _writeProject(
  String root, {
  required String sourceLocale,
  required List<String> targetLocales,
  required String source,
  Map<String, String> translations = const {},
  Map<String, Map<String, Object>>? platforms,
}) {
  final dialectDir = Directory(p.join(root, 'dialect'))..createSync();

  final lines = <String>[
    'source_locale: $sourceLocale',
    'target_locales: ${targetLocales.isEmpty ? '[]' : '[${targetLocales.join(', ')}]'}',
  ];
  if (platforms != null && platforms.isNotEmpty) {
    lines.add('platforms:');
    platforms.forEach((name, cfg) {
      lines.add('  $name:');
      cfg.forEach((k, v) {
        if (v is List) {
          lines.add('    $k: [${v.join(', ')}]');
        } else {
          lines.add('    $k: $v');
        }
      });
    });
  }
  File(
    p.join(dialectDir.path, 'dialect.yaml'),
  ).writeAsStringSync('${lines.join('\n')}\n');

  final srcDir = Directory(p.join(dialectDir.path, 'source'))..createSync();
  File(p.join(srcDir.path, '$sourceLocale.arb')).writeAsStringSync(source);

  final tDir = Directory(p.join(dialectDir.path, 'translations'))..createSync();
  for (final entry in translations.entries) {
    File(p.join(tDir.path, '${entry.key}.arb')).writeAsStringSync(entry.value);
  }
}
