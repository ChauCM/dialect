@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/arb/source_hash.dart';
import 'package:dialect/checks/check_runner.dart';
import 'package:dialect/cli.dart';
import 'package:dialect/project/dialect_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect lock (integration)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('dialect_lock_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<int> runLock(List<String> args) async {
      final code = await DialectCommandRunner().run(<String>[
        'lock',
        ...args,
        '--root',
        tmp.path,
      ]);
      return code ?? 0;
    }

    /// A project whose `vi` translation of `brand` is deliberately identical
    /// to the source — the canonical thing a lock exists to bless.
    void seed({
      String targetLocales = "['vi']",
      String viBrand = 'Stepo',
      String viMeta = '',
    }) {
      final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: $targetLocales
platforms:
  flutter:
    output: lib/l10n/
    format: arb
''');
      Directory(p.join(dialectDir.path, 'source')).createSync();
      File(p.join(dialectDir.path, 'source', 'en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "brand": "Stepo",
  "@brand": { "namespace": "common", "description": "The product name." }
}
''');
      Directory(p.join(dialectDir.path, 'translations')).createSync();
      File(p.join(dialectDir.path, 'translations', 'vi.arb')).writeAsStringSync(
        '''
{
  "@@locale": "vi",
  "brand": "$viBrand"${viMeta.isEmpty ? '' : ',\n  "@brand": $viMeta'}
}
''',
      );
    }

    ({bool locked, String? hash, String value}) entryOf(
      String locale,
      String key,
    ) {
      final arb = ArbParser.parse(
        File(
          p.join(tmp.path, 'dialect', 'translations', '$locale.arb'),
        ).readAsStringSync(),
      );
      final e = arb.entryFor(key)!;
      return (
        locked: e.metadata?.locked ?? false,
        hash: e.metadata?.sourceHash,
        value: e.value,
      );
    }

    test('locks and stamps the hash in one gesture', () async {
      seed();
      expect(entryOf('vi', 'brand').locked, isFalse);

      expect(await runLock(['brand']), 0);

      final after = entryOf('vi', 'brand');
      expect(after.locked, isTrue);
      expect(after.hash, computeSourceHash('Stepo'));
      expect(after.value, 'Stepo', reason: 'the value is never touched');
    });

    test('the lock it writes satisfies lock_integrity', () async {
      // The whole point: a bare `locked: true` is an error, so the command
      // must never produce one.
      seed();
      expect(await runLock(['brand']), 0);

      final project = DialectProject.load(tmp.path);
      final issues = runChecks(project).issues;
      expect(
        issues.where((i) => i.ruleName == 'lock_integrity'),
        isEmpty,
        reason: 'lock must write locked + source_hash together',
      );
    });

    test('silences source_equality for a deliberate identity', () async {
      seed();
      final before = runChecks(DialectProject.load(tmp.path)).issues;
      expect(
        before.where((i) => i.ruleName == 'source_equality'),
        isNotEmpty,
        reason: 'identical-to-source should flag before locking',
      );

      expect(await runLock(['brand']), 0);

      final after = runChecks(DialectProject.load(tmp.path)).issues;
      expect(after.where((i) => i.ruleName == 'source_equality'), isEmpty);
    });

    test('locks a single named locale, leaving others alone', () async {
      seed(targetLocales: "['vi', 'es']");
      File(
        p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
      ).writeAsStringSync('{\n  "@@locale": "es",\n  "brand": "Stepo"\n}\n');

      expect(await runLock(['brand', '--locale', 'vi']), 0);

      expect(entryOf('vi', 'brand').locked, isTrue);
      expect(entryOf('es', 'brand').locked, isFalse);
    });

    test('re-locking a locked-but-stale entry re-stamps it', () async {
      // Locked against an older English → locked + stale. Re-locking is the
      // "I re-reviewed it, it still holds" gesture.
      final stale = computeSourceHash('Stepo (beta)');
      seed(viMeta: '{ "locked": true, "source_hash": "$stale" }');
      expect(entryOf('vi', 'brand').hash, stale);

      expect(await runLock(['brand']), 0);

      final after = entryOf('vi', 'brand');
      expect(after.locked, isTrue);
      expect(after.hash, computeSourceHash('Stepo'));
    });

    test('re-running on an already-current lock changes nothing', () async {
      seed();
      expect(await runLock(['brand']), 0);
      final first = entryOf('vi', 'brand');

      expect(await runLock(['brand']), 0);

      expect(entryOf('vi', 'brand'), first);
    });

    test('--remove unlocks but keeps the hash', () async {
      seed();
      expect(await runLock(['brand']), 0);
      expect(entryOf('vi', 'brand').locked, isTrue);

      expect(await runLock(['brand', '--remove']), 0);

      final after = entryOf('vi', 'brand');
      expect(after.locked, isFalse);
      expect(
        after.hash,
        computeSourceHash('Stepo'),
        reason: 'unlocking keeps provenance so staleness is still tracked',
      );
    });

    test('errors when the key is not in the source', () async {
      seed();
      expect(await runLock(['nonexistent']), 65);
    });

    test('errors on an unknown locale', () async {
      seed();
      expect(await runLock(['brand', '--locale', 'de']), 64);
    });

    test('refuses to lock an empty translation', () async {
      seed(viBrand: '');
      expect(await runLock(['brand']), 65);
      expect(entryOf('vi', 'brand').locked, isFalse);
    });

    test('rejects a call that names no keys at all', () async {
      seed();
      expect(await runLock([]), 64);
    });

    group('selecting a set of keys', () {
      /// Three keys in one namespace plus one outside it — the shape of a
      /// page of hand-authored copy sitting next to unrelated strings.
      void seedPage() {
        seed();
        File(p.join(tmp.path, 'dialect', 'source', 'en.arb')).writeAsStringSync(
          '''
{
  "@@locale": "en",
  "brand": "Stepo",
  "@brand": { "namespace": "common", "description": "The product name." },
  "aboutTitle": "About",
  "@aboutTitle": { "namespace": "web", "description": "About page title." },
  "aboutBody": "What Stepo is for.",
  "@aboutBody": { "namespace": "web", "description": "About page body." },
  "aboutCta": "Get Stepo",
  "@aboutCta": { "namespace": "web", "description": "About page CTA." }
}
''',
        );
        File(
          p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
        ).writeAsStringSync('''
{
  "@@locale": "vi",
  "brand": "Stepo",
  "aboutTitle": "Giới thiệu",
  "aboutBody": "Stepo dùng để làm gì.",
  "aboutCta": "Tải Stepo"
}
''');
      }

      test('locks every key named on the command line', () async {
        seedPage();
        expect(await runLock(['aboutTitle', 'aboutBody', 'aboutCta']), 0);

        for (final k in ['aboutTitle', 'aboutBody', 'aboutCta']) {
          expect(entryOf('vi', k).locked, isTrue, reason: k);
        }
        expect(
          entryOf('vi', 'brand').locked,
          isFalse,
          reason: 'a key nobody named stays untouched',
        );
      });

      test('locks a whole namespace', () async {
        seedPage();
        expect(await runLock(['--namespace', 'web']), 0);

        for (final k in ['aboutTitle', 'aboutBody', 'aboutCta']) {
          expect(entryOf('vi', k).locked, isTrue, reason: k);
        }
        expect(entryOf('vi', 'brand').locked, isFalse);
      });

      test('a namespace and named keys combine', () async {
        seedPage();
        expect(await runLock(['brand', '--namespace', 'web']), 0);

        expect(entryOf('vi', 'brand').locked, isTrue);
        expect(entryOf('vi', 'aboutTitle').locked, isTrue);
      });

      test('errors on a namespace no key declares', () async {
        seedPage();
        expect(await runLock(['--namespace', 'nope']), 65);
        expect(entryOf('vi', 'aboutTitle').locked, isFalse);
      });

      test('unlocking takes the same selectors', () async {
        seedPage();
        expect(await runLock(['--namespace', 'web']), 0);
        expect(await runLock(['--namespace', 'web', '--remove']), 0);

        for (final k in ['aboutTitle', 'aboutBody', 'aboutCta']) {
          expect(entryOf('vi', k).locked, isFalse, reason: k);
          expect(
            entryOf('vi', k).hash,
            isNotNull,
            reason: 'unlock keeps the hash so staleness is still tracked',
          );
        }
      });

      test('locks nothing when one named key is unknown', () async {
        // All-or-nothing: a typo in a 13-key invocation should not half-apply
        // and leave the operator guessing which half landed.
        seedPage();
        expect(await runLock(['aboutTitle', 'aboutTypo']), 65);
        expect(entryOf('vi', 'aboutTitle').locked, isFalse);
      });

      test('names the migration when a locale is passed positionally', () async {
        // `dialect lock brand vi` used to mean "vi only". Now every positional
        // is a key, so this must not read as "no such key `vi`".
        seedPage();
        final err = StringBuffer();
        final code = await runZonedStderr(err, () => runLock(['brand', 'vi']));

        expect(code, 65);
        expect(err.toString(), contains('--locale vi'));
        expect(entryOf('vi', 'brand').locked, isFalse);
      });
    });
  });
}

/// Run [body] with stderr captured into [sink].
Future<int> runZonedStderr(StringBuffer sink, Future<int> Function() body) {
  return IOOverrides.runZoned(body, stderr: () => _CapturingStdout(sink));
}

class _CapturingStdout implements Stdout {
  _CapturingStdout(this.sink);
  final StringBuffer sink;

  @override
  void write(Object? object) => sink.write(object);

  @override
  void writeln([Object? object = '']) => sink.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
