@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `partial_locales:` marks a target locale that is still being filled in
/// slice by slice. Its missing keys become one progress note; everything else
/// is exactly as strict as for a finished locale.
void main() {
  group('partial_locales', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('dialect_partial_'));
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    /// Three source keys; `ko` carries [ko] (a JSON body, entries only).
    void seed({
      String partial = '[ko]',
      String targets = '[ko, es]',
      String ko = '"settingsTitle": "설정"',
      String es = '''
"settingsTitle": "Ajustes",
  "greetName": "Hola {name}",
  "signOut": "Cerrar sesión"''',
    }) {
      final d = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(d.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: $targets
${partial.isEmpty ? '' : 'partial_locales: $partial'}
platforms:
  flutter:
    output: lib/l10n/
    format: arb
''');
      Directory(p.join(d.path, 'source')).createSync();
      File(p.join(d.path, 'source', 'en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "settingsTitle": "Settings",
  "@settingsTitle": { "namespace": "settings", "description": "Title." },
  "greetName": "Hello {name}",
  "@greetName": {
    "namespace": "settings",
    "description": "Greeting.",
    "placeholders": { "name": { "type": "String" } }
  },
  "signOut": "Sign out",
  "@signOut": { "namespace": "settings", "description": "Sign out." }
}
''');
      Directory(p.join(d.path, 'translations')).createSync();
      File(p.join(d.path, 'translations', 'ko.arb')).writeAsStringSync(
        ko.isEmpty
            ? '{ "@@locale": "ko" }\n'
            : '{\n  "@@locale": "ko",\n  $ko\n}\n',
      );
      File(
        p.join(d.path, 'translations', 'es.arb'),
      ).writeAsStringSync('{\n  "@@locale": "es",\n  $es\n}\n');
    }

    Future<({int code, String out, String err})> check(
      List<String> args,
    ) async {
      final out = StringBuffer();
      final err = StringBuffer();
      var code = 0;
      await IOOverrides.runZoned(
        () async {
          code =
              await DialectCommandRunner().run(['check', ...args, tmp.path]) ??
              0;
        },
        stdout: () => _Capture(out),
        stderr: () => _Capture(err),
      );
      return (code: code, out: out.toString(), err: err.toString());
    }

    test('a partial locale with missing keys passes --strict with a '
        'one-line summary', () async {
      seed();
      final r = await check(['--strict']);
      expect(r.out, contains('ko: 1 of 3 keys translated'));
      expect(r.out, isNot(contains('Missing translation for key')));
      expect(r.code, 0, reason: r.out);
    });

    test('the same project without the marker still fails', () async {
      seed(partial: '');
      final r = await check(['--strict']);
      expect(r.code, 1);
      expect(r.out, contains('Missing translation for key `greetName`'));
      expect(r.out, contains('ko.arb'));
    });

    test('a non-partial locale keeps failing beside a partial one', () async {
      seed(es: '"settingsTitle": "Ajustes"');
      final r = await check(['--strict']);
      expect(r.code, 1);
      expect(r.out, contains('Missing translation for key `signOut`'));
      expect(r.out, contains('ko: 1 of 3 keys translated'));
    });

    test('a placeholder error on an existing key still fails', () async {
      // `greetName` exists in ko but drops {name}.
      seed(ko: '"greetName": "안녕하세요"');
      final soft = await check([]);
      expect(soft.code, 1, reason: soft.out);
      expect(soft.out, contains('placeholder'));
      expect((await check(['--strict'])).code, 1);
    });

    test('a stale translation on an existing key is still reported', () async {
      seed(
        ko:
            '"settingsTitle": "설정",\n'
            '  "@settingsTitle": { "source_hash": "0000000000000000" }',
      );
      final r = await check(['--strict']);
      expect(r.out, contains('stale_translation'));
      expect(r.code, 1);
    });

    test('a partial locale not in target_locales is a config error', () async {
      seed(partial: '[fr]');
      final r = await check(['--strict']);
      expect(r.code, 65);
      expect(r.err, contains('partial_locales'));
      expect(r.err, contains('`fr`'));
      expect(r.err, contains('target_locales'));
    });

    test('a malformed partial_locales is a config error', () async {
      seed(partial: 'ko');
      expect((await check([])).code, 65);
      seed(partial: '[1]');
      expect((await check([])).code, 65);
    });

    test('a fully translated partial locale says it can be made complete', () {
      seed(
        ko:
            '"settingsTitle": "설정",\n'
            '  "greetName": "안녕하세요 {name}",\n'
            '  "signOut": "로그아웃"',
      );
      return check(['--strict']).then((r) {
        expect(r.code, 0, reason: r.out);
        expect(
          r.out,
          contains(
            'ko: 3 of 3 keys translated — complete; remove `ko` from '
            'partial_locales',
          ),
        );
      });
    });

    test('a zero-key partial locale reports 0 of N', () async {
      seed(ko: '');
      final r = await check(['--strict']);
      expect(r.code, 0, reason: r.out);
      expect(r.out, contains('ko: 0 of 3 keys translated'));
    });

    test('summary counts use thousands separators', () async {
      seed();
      final src = File(p.join(tmp.path, 'dialect', 'source', 'en.arb'));
      final body = StringBuffer('{\n  "@@locale": "en"');
      for (var i = 0; i < 2520; i++) {
        body.write(',\n  "key$i": "Value $i"');
        body.write(
          ',\n  "@key$i": { "namespace": "settings", "description": "d" }',
        );
      }
      body.write('\n}\n');
      src.writeAsStringSync(body.toString());
      File(
        p.join(tmp.path, 'dialect', 'translations', 'ko.arb'),
      ).writeAsStringSync('{ "@@locale": "ko", "key0": "값 0", "key1": "값 1" }');
      File(
        p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
      ).writeAsStringSync('{ "@@locale": "es" }');
      final r = await check(['--strict']);
      expect(r.out, contains('ko: 2 of 2,520 keys translated'));
    });

    test('sync still writes a partial locale', () async {
      seed();
      final code = await DialectCommandRunner().run(['sync', tmp.path]);
      expect(code, 0);
      final out = File(p.join(tmp.path, 'lib', 'l10n', 'app_ko.arb'));
      expect(out.existsSync(), isTrue);
      expect(out.readAsStringSync(), contains('설정'));
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
