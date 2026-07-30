@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/arb/source_hash.dart';
import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect accept (integration)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('dialect_accept_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<int> runAccept(List<String> args) async {
      final code = await DialectCommandRunner().run(<String>[
        'accept',
        ...args,
        '--root',
        tmp.path,
      ]);
      return code ?? 0;
    }

    /// Seed a project whose vi `greeting` carries a STALE hash (stamped
    /// against an older English), so `accept` has something to re-bless.
    void seedStale({String targetLocales = "['vi']"}) {
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
  "greeting": "Hello there",
  "@greeting": { "namespace": "common", "description": "A greeting." }
}
''');
      Directory(p.join(dialectDir.path, 'translations')).createSync();
      // Hash stamped against a different English → stale.
      final staleHash = computeSourceHash('Hello');
      File(p.join(dialectDir.path, 'translations', 'vi.arb')).writeAsStringSync(
        '''
{
  "@@locale": "vi",
  "greeting": "Xin chào",
  "@greeting": { "source_hash": "$staleHash" }
}
''',
      );
    }

    String hashOf(String locale, String key) {
      final arb = ArbParser.parse(
        File(
          p.join(tmp.path, 'dialect', 'translations', '$locale.arb'),
        ).readAsStringSync(),
      );
      return arb.entryFor(key)!.metadata!.sourceHash!;
    }

    String valueOf(String locale, String key) {
      final arb = ArbParser.parse(
        File(
          p.join(tmp.path, 'dialect', 'translations', '$locale.arb'),
        ).readAsStringSync(),
      );
      return arb.entryFor(key)!.value;
    }

    test('re-stamps a stale translation to the current source hash', () async {
      seedStale();
      final current = computeSourceHash('Hello there');
      expect(hashOf('vi', 'greeting'), isNot(current)); // stale before

      expect(await runAccept(['greeting']), 0);

      expect(hashOf('vi', 'greeting'), current); // fresh after
      expect(valueOf('vi', 'greeting'), 'Xin chào'); // value untouched
    });

    test('accepts a single named locale', () async {
      seedStale(targetLocales: "['vi', 'es']");
      // Give es a value too, also stale.
      File(
        p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
      ).writeAsStringSync('''
{
  "@@locale": "es",
  "greeting": "Hola",
  "@greeting": { "source_hash": "${computeSourceHash('Hello')}" }
}
''');
      final current = computeSourceHash('Hello there');

      expect(await runAccept(['greeting', '--locale', 'vi']), 0);

      expect(hashOf('vi', 'greeting'), current); // vi blessed
      expect(hashOf('es', 'greeting'), isNot(current)); // es untouched
    });

    test('errors when the key is not in the source', () async {
      seedStale();
      expect(await runAccept(['nonexistent']), 65);
    });

    test('errors when the locale is not a target', () async {
      seedStale();
      expect(await runAccept(['greeting', '--locale', 'fr']), 64);
    });

    test('accepts a whole namespace at once', () async {
      // An English edit that touches a screen leaves a screen's worth of
      // stale translations; blessing them should not be a shell loop.
      seedStale();
      File(p.join(tmp.path, 'dialect', 'source', 'en.arb')).writeAsStringSync(
        '''
{
  "@@locale": "en",
  "greeting": "Hello there",
  "@greeting": { "namespace": "web", "description": "Greeting." },
  "farewell": "See you",
  "@farewell": { "namespace": "web", "description": "Farewell." }
}
''',
      );
      final stale = computeSourceHash('Hello');
      File(
        p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
      ).writeAsStringSync('''
{
  "@@locale": "vi",
  "greeting": "Xin chào",
  "@greeting": { "source_hash": "$stale" },
  "farewell": "Hẹn gặp lại",
  "@farewell": { "source_hash": "$stale" }
}
''');

      expect(await runAccept(['--namespace', 'web']), 0);

      expect(hashOf('vi', 'greeting'), computeSourceHash('Hello there'));
      expect(hashOf('vi', 'farewell'), computeSourceHash('See you'));
      expect(valueOf('vi', 'farewell'), 'Hẹn gặp lại');
    });

    test('errors when the translation is missing/empty', () async {
      seedStale();
      // Overwrite vi to drop the value.
      File(
        p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
      ).writeAsStringSync('{ "@@locale": "vi" }');
      expect(await runAccept(['greeting']), 65);
    });

    test('is a no-op (exit 0) on an already-fresh translation', () async {
      seedStale();
      expect(await runAccept(['greeting']), 0); // makes it fresh
      final before = File(
        p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
      ).readAsStringSync();
      expect(await runAccept(['greeting']), 0); // second run, still fresh
      final after = File(
        p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
      ).readAsStringSync();
      expect(after, before); // untouched
    });
  });
}
