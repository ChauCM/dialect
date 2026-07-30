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

    /// Run sync and hand back everything it printed, so a test can assert on
    /// the warnings a person actually reads.
    Future<String> runSyncCapturingStdout([
      List<String> extraArgs = const [],
    ]) async {
      final buffer = StringBuffer();
      await IOOverrides.runZoned(
        () => runSync(extraArgs),
        stdout: () => _CapturingStdout(buffer),
      );
      return buffer.toString();
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

    test(
      'translation outputs include filtered keys (regression: B3/B4)',
      () async {
        // Before the B3 fix, sync read `entry.namespace` directly on
        // translation entries (which carry no @key blocks by convention),
        // dropped every key, and emitted 3-line stubs. A subsequent
        // re-sync then misreported "nothing to do" because the stale stub
        // matched the freshly-generated empty stub byte-for-byte (B4).
        _writeProject(
          tmp.path,
          sourceLocale: 'en',
          targetLocales: ['es'],
          source: '''
{
  "@@locale": "en",
  "commonCancel": "Cancel",
  "@commonCancel": { "namespace": "common" }
}
''',
          translations: {
            'es': '{ "@@locale": "es", "commonCancel": "Cancelar" }',
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
        final esOut = File(
          p.join(tmp.path, 'lib', 'l10n', 'app_es.arb'),
        ).readAsStringSync();
        expect(
          esOut,
          contains('Cancelar'),
          reason: 'namespace filter must let translated keys through',
        );
      },
    );

    test('--force runs end-to-end and produces canonical output', () async {
      // The semantic contract — "write even if content matches" — is
      // covered at the unit layer in test/adapters tests via the
      // _maybeWrite branch. This integration test just proves the
      // --force flag is plumbed through to sync without crashing and
      // still produces canonical output bytes.
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
      final canonical = File(
        p.join(tmp.path, 'lib', 'l10n', 'app_es.arb'),
      ).readAsStringSync();

      expect(await runSync(['--force']), 0);
      expect(
        File(p.join(tmp.path, 'lib', 'l10n', 'app_es.arb')).readAsStringSync(),
        canonical,
      );
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

    test('icu-json: emits flat <locale>.json with ICU preserved', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: ['ar'],
        source: '''
{
  "@@locale": "en",
  "checkoutItemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "@checkoutItemCount": { "namespace": "checkout", "description": "Cart line." },
  "commonCancel": "Cancel",
  "@commonCancel": { "namespace": "common", "description": "Cancel." }
}
''',
        translations: {
          'ar':
              '{ "@@locale": "ar", "checkoutItemCount": "{count, plural, other{{count} عنصر}}", "commonCancel": "إلغاء" }',
        },
        platforms: {
          'backend': {
            'output': 'api/locales/',
            'format': 'icu-json',
            'namespaces': ['common', 'checkout'],
          },
        },
      );

      expect(await runSync(), 0);

      final en = File(p.join(tmp.path, 'api', 'locales', 'en.json'));
      expect(en.existsSync(), isTrue);
      expect(
        en.readAsStringSync(),
        '{\n'
        '  "checkoutItemCount": "{count, plural, =1{1 item} other{{count} items}}",\n'
        '  "commonCancel": "Cancel"\n'
        '}\n',
      );
      // Translation file: no @@locale, no metadata, just key→value.
      final ar = File(p.join(tmp.path, 'api', 'locales', 'ar.json'));
      expect(ar.readAsStringSync(), contains('"commonCancel": "إلغاء"'));
      expect(ar.readAsStringSync(), isNot(contains('@@locale')));
    });

    test('flat-json: collapses plurals to the other branch', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: const [],
        source: '''
{
  "@@locale": "en",
  "checkoutItemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "@checkoutItemCount": { "namespace": "common", "description": "Cart line." }
}
''',
        platforms: {
          'gateway': {
            'output': 'gateway/locales/',
            'format': 'flat-json',
            'namespaces': ['common'],
          },
        },
      );

      expect(await runSync(), 0);

      final en = File(p.join(tmp.path, 'gateway', 'locales', 'en.json'));
      expect(
        en.readAsStringSync(),
        '{\n  "checkoutItemCount": "{count} items"\n}\n',
      );
    });

    test('--dry-run reports would-change, writes nothing, exits 1', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: const [],
        source:
            '{ "@@locale": "en", "commonCancel": "Cancel", "@commonCancel": { "namespace": "common" } }',
        platforms: {
          'flutter': {'output': 'lib/l10n/', 'format': 'arb', 'namespaces': []},
        },
      );
      expect(await runSync(['--dry-run']), 1);
      // Nothing written — not even the output directory.
      expect(Directory(p.join(tmp.path, 'lib', 'l10n')).existsSync(), isFalse);

      // After a real sync, --dry-run is clean and exits 0.
      expect(await runSync(), 0);
      expect(await runSync(['--dry-run']), 0);
    });

    test('--platform syncs only the named platform', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: const [],
        source:
            '{ "@@locale": "en", "commonCancel": "Cancel", "@commonCancel": { "namespace": "common" } }',
        platforms: {
          'flutter': {'output': 'lib/l10n/', 'format': 'arb', 'namespaces': []},
          'backend': {
            'output': 'api/locales/',
            'format': 'icu-json',
            'namespaces': [],
          },
        },
      );
      expect(await runSync(['--platform', 'backend']), 0);
      expect(
        File(p.join(tmp.path, 'api', 'locales', 'en.json')).existsSync(),
        isTrue,
      );
      // flutter was not selected — no ARB output.
      expect(Directory(p.join(tmp.path, 'lib', 'l10n')).existsSync(), isFalse);
    });

    test('--platform with an unknown name errors (exit 64)', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: const [],
        source: '{ "@@locale": "en", "k": "v", "@k": { "namespace": "c" } }',
        platforms: {
          'flutter': {'output': 'lib/l10n/', 'format': 'arb', 'namespaces': []},
        },
      );
      expect(await runSync(['--platform', 'nope']), 64);
    });

    test('unknown format is skipped with a hint, not an error', () async {
      _writeProject(
        tmp.path,
        sourceLocale: 'en',
        targetLocales: const [],
        source:
            '{ "@@locale": "en", "k": "v", "@k": { "namespace": "common" } }',
        platforms: {
          'weird': {'output': 'out/', 'format': 'toml', 'namespaces': []},
        },
      );
      expect(await runSync(), 0);
      expect(Directory(p.join(tmp.path, 'out')).existsSync(), isFalse);
    });

    group('orphan keys (non-destructive guard)', () {
      // Reproduce the field incident: a key gets added straight to the
      // generated output (app_en.arb) and never round-tripped through the
      // source. A naive regenerate would silently delete it.
      void seedOrphan(String root) {
        _writeProject(
          root,
          sourceLocale: 'en',
          targetLocales: ['es'],
          source: '{ "@@locale": "en", "keep": "Keep" }',
          translations: {'es': '{ "@@locale": "es", "keep": "Mantener" }'},
          platforms: {
            'flutter': {'output': 'lib/l10n/', 'format': 'arb'},
          },
        );
        // A human/agent edits the generated app_en.arb by hand — and, as in
        // the real field incident, also drops a translated value straight
        // into app_es.arb. Neither round-tripped through the source.
        final outDir = Directory(p.join(root, 'lib', 'l10n'))
          ..createSync(recursive: true);
        File(p.join(outDir.path, 'app_en.arb')).writeAsStringSync(
          '{\n'
          '  "@@locale": "en",\n\n'
          '  "keep": "Keep",\n\n'
          '  "orphan": "Straight into the output",\n'
          '  "@orphan": {\n'
          '    "namespace": "common",\n'
          '    "description": "Added by hand."\n'
          '  }\n'
          '}\n',
        );
        File(p.join(outDir.path, 'app_es.arb')).writeAsStringSync(
          '{\n'
          '  "@@locale": "es",\n\n'
          '  "keep": "Mantener",\n\n'
          '  "orphan": "Directo a la salida"\n'
          '}\n',
        );
      }

      test('refuses to sync and writes nothing (exit 65)', () async {
        seedOrphan(tmp.path);
        final before = File(
          p.join(tmp.path, 'lib', 'l10n', 'app_en.arb'),
        ).readAsStringSync();

        expect(await runSync(), 65);

        // The orphan is still there — nothing was deleted.
        final after = File(
          p.join(tmp.path, 'lib', 'l10n', 'app_en.arb'),
        ).readAsStringSync();
        expect(after, before, reason: 'refusal must not touch the output');
        expect(after, contains('orphan'));
      });

      test('--dry-run also refuses (exit 1) and writes nothing', () async {
        seedOrphan(tmp.path);
        expect(await runSync(['--dry-run']), 1);
        expect(
          File(
            p.join(tmp.path, 'lib', 'l10n', 'app_en.arb'),
          ).readAsStringSync(),
          contains('orphan'),
        );
      });

      test('--adopt pulls the orphan into the source, then syncs', () async {
        seedOrphan(tmp.path);

        expect(await runSync(['--adopt']), 0);

        // The key is now in the canonical source, with its @key metadata.
        final source = File(
          p.join(tmp.path, 'dialect', 'source', 'en.arb'),
        ).readAsStringSync();
        expect(source, contains('"orphan"'));
        expect(source, contains('"@orphan"'));
        expect(source, contains('"namespace": "common"'));
        expect(source, contains('Added by hand.'));

        // The Spanish value that lived only in app_es.arb is recovered into
        // the translation source — not dropped on regenerate.
        final esSource = File(
          p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
        ).readAsStringSync();
        expect(esSource, contains('Directo a la salida'));

        // And both outputs still carry the key after regenerating.
        expect(
          File(
            p.join(tmp.path, 'lib', 'l10n', 'app_en.arb'),
          ).readAsStringSync(),
          contains('orphan'),
        );
        expect(
          File(
            p.join(tmp.path, 'lib', 'l10n', 'app_es.arb'),
          ).readAsStringSync(),
          contains('Directo a la salida'),
        );

        // A follow-up sync is now clean — the trap is closed.
        expect(await runSync(), 0);
      });

      test(
        '--adopt says nothing is left to do when metadata came back too',
        () async {
          // Every orphan here carries namespace + description, so the correct
          // response is "nothing further" — and the operator should not have to
          // open the source and read @key blocks by hand to learn that.
          seedOrphan(tmp.path);

          final out = await runSyncCapturingStdout(['--adopt']);

          expect(out, contains('All 1 key came back'));
          expect(
            out,
            isNot(contains('re-run `dialect sync`')),
            reason: 'this same run regenerates the outputs',
          );
          expect(out, isNot(contains('still need')));
        },
      );

      test('--adopt names the adopted keys that still need metadata', () async {
        seedOrphan(tmp.path);
        // A second orphan with no @key block at all: this is the one that
        // will be dropped from every filtering platform until it gets a
        // namespace, and it must not hide inside a list of complete keys.
        final outPath = p.join(tmp.path, 'lib', 'l10n', 'app_en.arb');
        File(outPath).writeAsStringSync(
          File(outPath).readAsStringSync().replaceFirst(
            '  "orphan": "Straight into the output",',
            '  "bare": "No metadata at all",\n'
                '  "orphan": "Straight into the output",',
          ),
        );

        final out = await runSyncCapturingStdout(['--adopt']);

        expect(out, contains('1 of 2 keys still needs'));
        expect(out, contains('bare'));
        expect(
          out,
          isNot(contains('All 2 keys came back')),
          reason: 'silence must mean "complete", so it cannot be printed here',
        );
      });

      test(
        'the refusal names --adopt as the migration off the old habit',
        () async {
          // A project that learned to avoid `sync` back when it deleted keys
          // meets this refusal exactly once, caused by its own workaround.
          seedOrphan(tmp.path);
          final err = StringBuffer();
          await IOOverrides.runZoned(
            runSync,
            stderr: () => _CapturingStdout(err),
          );

          expect(err.toString(), contains('one-time migration'));
        },
      );

      test('--prune drops the orphan on explicit opt-in', () async {
        seedOrphan(tmp.path);

        expect(await runSync(['--prune']), 0);

        final out = File(
          p.join(tmp.path, 'lib', 'l10n', 'app_en.arb'),
        ).readAsStringSync();
        expect(out, isNot(contains('orphan')));
        expect(out, contains('keep'));
        // Source was never touched by prune.
        expect(
          File(
            p.join(tmp.path, 'dialect', 'source', 'en.arb'),
          ).readAsStringSync(),
          isNot(contains('orphan')),
        );
      });

      test('clean project (no orphans) still syncs normally', () async {
        _writeProject(
          tmp.path,
          sourceLocale: 'en',
          targetLocales: ['es'],
          source: '{ "@@locale": "en", "keep": "Keep" }',
          translations: {'es': '{ "@@locale": "es", "keep": "Mantener" }'},
          platforms: {
            'flutter': {'output': 'lib/l10n/', 'format': 'arb'},
          },
        );
        expect(await runSync(), 0);
        // Second sync sees the outputs it just wrote — no false orphan.
        expect(await runSync(), 0);
      });
    });

    group('namespace routing warnings', () {
      // One source feeding an app, a backend and a website is the shape the
      // tool exists for, and in it every platform excludes most namespaces on
      // purpose. Warning per-platform meant three paragraphs on every healthy
      // sync, which buries the one line that would matter.
      const threeStacks = '''
{
  "@@locale": "en",
  "commonCancel": "Cancel",
  "@commonCancel": { "namespace": "common", "description": "Back out." },
  "pushNewStep": "New step",
  "@pushNewStep": { "namespace": "push", "description": "Push body." },
  "landingHero": "Share the journey",
  "@landingHero": { "namespace": "landing", "description": "Landing hero." }
}
''';

      Map<String, Map<String, Object>> platformsFor({
        List<String> flutter = const ['common'],
        List<String> backend = const ['push'],
        List<String> web = const ['landing'],
      }) => {
        'flutter': {
          'output': 'lib/l10n/',
          'format': 'arb',
          'namespaces': flutter,
        },
        'backend': {
          'output': 'api/locales/',
          'format': 'flat-json',
          'namespaces': backend,
        },
        'web': {
          'output': 'web/locales/',
          'format': 'icu-json',
          'namespaces': web,
        },
      };

      test('stays quiet when every namespace reaches some platform', () async {
        _writeProject(
          tmp.path,
          sourceLocale: 'en',
          targetLocales: const [],
          source: threeStacks,
          platforms: platformsFor(),
        );

        final out = await runSyncCapturingStdout();
        expect(out, isNot(contains('reach no platform')));
        expect(out, contains('dialect sync: wrote'));
      });

      test('names a namespace that reaches no platform at all', () async {
        _writeProject(
          tmp.path,
          sourceLocale: 'en',
          targetLocales: const [],
          source: threeStacks,
          // Nobody claims `landing`, so those keys are emitted nowhere.
          platforms: platformsFor(web: const ['marketing']),
        );

        final out = await runSyncCapturingStdout();
        expect(out, contains('reach no platform'));
        expect(out, contains('landing'));
        expect(out, contains('1 key(s)'));
        // The namespaces other platforms DO claim are not the complaint.
        expect(out, isNot(contains('    push  —')));
        expect(out, isNot(contains('    common  —')));
      });

      test(
        'judges coverage across every platform, not just --platform',
        () async {
          _writeProject(
            tmp.path,
            sourceLocale: 'en',
            targetLocales: const [],
            source: threeStacks,
            platforms: platformsFor(),
          );

          // Syncing one platform must not call the other two's namespaces
          // homeless — they have a home, this run just is not writing it.
          final out = await runSyncCapturingStdout(['--platform', 'backend']);
          expect(out, isNot(contains('reach no platform')));
        },
      );

      test('an unfiltered platform means nothing can be unrouted', () async {
        _writeProject(
          tmp.path,
          sourceLocale: 'en',
          targetLocales: const [],
          source: threeStacks,
          platforms: {
            'flutter': {
              'output': 'lib/l10n/',
              'format': 'arb',
              'namespaces': <String>[],
            },
          },
        );

        final out = await runSyncCapturingStdout();
        expect(out, isNot(contains('reach no platform')));
      });
    });
  });
}

/// A [Stdout] stand-in that collects what a command writes. Only `write` and
/// `writeln` are real; anything else a command reached for would be a surprise
/// worth failing on, which is what the inherited [noSuchMethod] does.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
