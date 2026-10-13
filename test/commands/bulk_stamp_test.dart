@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/arb/source_hash.dart';
import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The bulk forms exist for a writer outside Dialect (an import rail, a
/// script) that writes `<locale>.arb` itself: `dialect accept --all` stamps
/// every translation it wrote, and `dialect lock --identical` locks the ones
/// that are deliberate copies of the source, so the rail never computes a
/// source_hash and never trips `source_equality`.
void main() {
  group('bulk lock / accept', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('dialect_bulk_'));
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    const sourceValues = {
      'brandName': 'Stepo',
      'cancel': 'Cancel',
      'greet': 'Hello',
      'save': 'Save',
      'year': 'YYYY',
    };

    String srcHash(String key) => computeSourceHash(sourceValues[key]!);

    File koFile() =>
        File(p.join(tmp.path, 'dialect', 'translations', 'ko.arb'));
    File esFile() =>
        File(p.join(tmp.path, 'dialect', 'translations', 'es.arb'));

    /// ko as an outside rail leaves it: no stamps, two deliberate copies
    /// (`brandName`, `year`), one translation stamped for an older source
    /// (`save`), one already current (`greet`), and `cancel` not done yet.
    void seed() {
      final d = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(d.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [ko, es]
partial_locales: [ko, es]
platforms:
  flutter:
    output: lib/l10n/
    format: arb
''');
      Directory(p.join(d.path, 'source')).createSync();
      final src = StringBuffer('{\n  "@@locale": "en"');
      sourceValues.forEach((k, v) {
        src.write(
          ',\n  "$k": "$v",\n'
          '  "@$k": { "namespace": "common", "description": "$k." }',
        );
      });
      src.write('\n}\n');
      File(
        p.join(d.path, 'source', 'en.arb'),
      ).writeAsStringSync(src.toString());
      Directory(p.join(d.path, 'translations')).createSync();
      koFile().writeAsStringSync('''
{
  "@@locale": "ko",

  "brandName": "Stepo",

  "greet": "안녕하세요",
  "@greet": {
    "source_hash": "${srcHash('greet')}"
  },

  "save": "저장",
  "@save": {
    "source_hash": "0123456789abcdef"
  },

  "year": "YYYY"
}
''');
      esFile().writeAsStringSync('''
{
  "@@locale": "es",

  "brandName": "Stepo"
}
''');
    }

    Future<({int code, String out})> run(
      List<String> args, {
      bool root = true,
    }) async {
      final buf = StringBuffer();
      var code = 0;
      await IOOverrides.runZoned(() async {
        code =
            await DialectCommandRunner().run([
              ...args,
              if (root) ...['--root', tmp.path],
            ]) ??
            0;
      }, stdout: () => _Capture(buf));
      return (code: code, out: buf.toString());
    }

    /// A canonical ARB split into its (key, @key) groups, keyed by key.
    Map<String, String> groups(File f) {
      final out = <String, String>{};
      for (final g in f.readAsStringSync().split('\n\n')) {
        final m = RegExp(r'"([^"@][^"]*)":').firstMatch(g);
        out[m == null ? '<head>' : m.group(1)!] = g.trim();
      }
      return out;
    }

    ({bool locked, String? hash}) stampOf(String key) {
      final e = ArbParser.parse(koFile().readAsStringSync()).entryFor(key)!;
      return (
        locked: e.metadata?.locked ?? false,
        hash: e.metadata?.sourceHash,
      );
    }

    /// Groups whose text differs between [before] and now.
    Set<String> changedKeys(Map<String, String> before) {
      final after = groups(koFile());
      return {
        for (final k in {...before.keys, ...after.keys})
          if (before[k] != after[k]) k,
      };
    }

    group('lock --identical', () {
      test('locks exactly the translations equal to the source, with the '
          'hash', () async {
        seed();
        final before = groups(koFile());
        final r = await run(['lock', '--identical', '--locale', 'ko']);
        expect(r.code, 0, reason: r.out);
        expect(changedKeys(before), {'brandName', 'year'});
        expect(stampOf('brandName'), (
          locked: true,
          hash: srcHash('brandName'),
        ));
        expect(stampOf('year'), (locked: true, hash: srcHash('year')));
        expect(stampOf('greet').locked, isFalse);
        expect(r.out, contains('locked 2 keys'));
      });

      test('touches nothing else: other locales and other keys are '
          'byte-identical', () async {
        seed();
        final es = esFile().readAsStringSync();
        final before = groups(koFile());
        await run(['lock', '--identical', '--locale', 'ko']);
        expect(esFile().readAsStringSync(), es);
        for (final k in ['greet', 'save', '<head>']) {
          expect(groups(koFile())[k], before[k], reason: k);
        }
      });

      test('is idempotent: a second run writes nothing', () async {
        seed();
        await run(['lock', '--identical', '--locale', 'ko']);
        final once = koFile().readAsStringSync();
        final r = await run(['lock', '--identical', '--locale', 'ko']);
        expect(r.code, 0);
        expect(koFile().readAsStringSync(), once);
        expect(r.out, contains('already locked and current: 2 keys'));
      });

      test('without --locale it covers every target locale', () async {
        seed();
        await run(['lock', '--identical']);
        final es = ArbParser.parse(esFile().readAsStringSync());
        expect(es.entryFor('brandName')!.metadata?.locked, isTrue);
        expect(stampOf('year').locked, isTrue);
      });

      test('says so when nothing is identical', () async {
        seed();
        final before = koFile().readAsStringSync();
        final r = await run(['lock', '--identical', '--locale', 'ko', 'save']);
        expect(r.code, 0);
        expect(r.out, contains('identical to the source'));
        expect(koFile().readAsStringSync(), before);
      });

      test('named keys narrow it', () async {
        seed();
        await run(['lock', '--identical', '--locale', 'ko', 'year']);
        expect(stampOf('year').locked, isTrue);
        expect(stampOf('brandName').locked, isFalse);
      });

      test('lets a strict check pass source_equality', () async {
        seed();
        await run(['lock', '--identical']);
        await run(['accept', '--all']);
        final r = await run(['check', '--strict', tmp.path], root: false);
        expect(r.out, isNot(contains('source_equality')));
        expect(r.code, 0, reason: r.out);
      });
    });

    group('accept --all', () {
      test('stamps every translation with no stamp or a stale one', () async {
        seed();
        final before = groups(koFile());
        final r = await run(['accept', '--all', '--locale', 'ko']);
        expect(r.code, 0, reason: r.out);
        // greet was already current, cancel does not exist.
        expect(changedKeys(before), {'brandName', 'save', 'year'});
        for (final k in ['brandName', 'save', 'year']) {
          expect(stampOf(k).hash, srcHash(k), reason: k);
        }
        expect(koFile().readAsStringSync(), isNot(contains('"cancel"')));
        expect(r.out, contains('accepted 3 keys'));
        expect(r.out, contains('already current: 1 key'));
      });

      test('keeps the locked flag and the value', () async {
        seed();
        await run(['lock', '--identical', '--locale', 'ko']);
        final before = ArbParser.parse(koFile().readAsStringSync());
        await run(['accept', '--all', '--locale', 'ko']);
        final after = ArbParser.parse(koFile().readAsStringSync());
        for (final e in before.entries) {
          expect(after.entryFor(e.key)!.value, e.value);
          expect(
            after.entryFor(e.key)!.metadata?.locked ?? false,
            e.metadata?.locked ?? false,
          );
        }
      });

      test('is idempotent and leaves other locales alone', () async {
        seed();
        final es = esFile().readAsStringSync();
        await run(['accept', '--all', '--locale', 'ko']);
        final once = koFile().readAsStringSync();
        final r = await run(['accept', '--all', '--locale', 'ko']);
        expect(r.code, 0);
        expect(koFile().readAsStringSync(), once);
        expect(esFile().readAsStringSync(), es);
      });

      test('cannot be combined with named keys or --namespace', () async {
        seed();
        final before = koFile().readAsStringSync();
        expect((await run(['accept', '--all', 'greet'])).code, 64);
        expect((await run(['accept', '--all', '-n', 'common'])).code, 64);
        expect(koFile().readAsStringSync(), before);
      });
    });

    test('single-key forms are unchanged', () async {
      seed();
      final before = groups(koFile());
      await run(['lock', 'year', '--locale', 'ko']);
      expect(changedKeys(before), {'year'});
      await run(['accept', 'save', '--locale', 'ko']);
      expect(changedKeys(before), {'year', 'save'});
    });
  });
}

class _Capture implements Stdout {
  _Capture(this.sink);
  final StringBuffer sink;

  @override
  void write(Object? object) => sink.write(object);

  @override
  void writeln([Object? object = '']) => sink.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
