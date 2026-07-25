@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/arb/source_hash.dart';
import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect check --fix --no-stamp', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('dialect_nostamp_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<int> runCheck(List<String> args) async =>
        await DialectCommandRunner().run(<String>[
          'check',
          tmp.path,
          ...args,
        ]) ??
        0;

    /// A hand-authored locale: flat `"key": "value"` pairs, no `@key` blocks
    /// at all — exactly what a translator/agent writes on a first pass.
    void seed() {
      final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: ['vi']
platforms:
  flutter:
    output: lib/l10n/
    format: arb
''');
      Directory(p.join(dialectDir.path, 'source')).createSync();
      File(p.join(dialectDir.path, 'source', 'en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "greeting": "Hello",
  "@greeting": { "namespace": "common", "description": "A greeting." },
  "farewell": "Goodbye",
  "@farewell": { "namespace": "common", "description": "A farewell." }
}
''');
      Directory(p.join(dialectDir.path, 'translations')).createSync();
      File(p.join(dialectDir.path, 'translations', 'vi.arb')).writeAsStringSync(
        '''
{
  "@@locale": "vi",
  "greeting": "Xin chào",
  "farewell": "Tạm biệt"
}
''',
      );
    }

    String viText() => File(
      p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
    ).readAsStringSync();

    String? hashOf(String key) =>
        ArbParser.parse(viText()).entryFor(key)?.metadata?.sourceHash;

    test('normalizes without stamping new hashes', () async {
      seed();
      expect(await runCheck(['--fix', '--no-stamp']), 0);

      expect(hashOf('greeting'), isNull);
      expect(hashOf('farewell'), isNull);
      expect(viText(), isNot(contains('source_hash')));
      // The values survive untouched — this is a formatting pass.
      expect(viText(), contains('Xin chào'));
      expect(viText(), contains('Tạm biệt'));
    });

    test('keeps the authoring diff small vs. a stamping fix', () async {
      seed();
      await runCheck(['--fix', '--no-stamp']);
      final unstampedLines = viText().split('\n').length;

      await runCheck(['--fix']);
      final stampedLines = viText().split('\n').length;

      expect(
        unstampedLines,
        lessThan(stampedLines),
        reason: 'the whole point is a smaller first review',
      );
    });

    test('only DEFERS stamping — the next plain --fix stamps', () async {
      seed();
      await runCheck(['--fix', '--no-stamp']);
      expect(hashOf('greeting'), isNull);

      expect(await runCheck(['--fix']), 0);

      expect(hashOf('greeting'), computeSourceHash('Hello'));
      expect(hashOf('farewell'), computeSourceHash('Goodbye'));
    });

    test('never strips an existing hash', () async {
      seed();
      // Stamp everything first, then run the authoring pass again.
      await runCheck(['--fix']);
      final stamped = hashOf('greeting');
      expect(stamped, isNotNull);

      expect(await runCheck(['--fix', '--no-stamp']), 0);

      expect(
        hashOf('greeting'),
        stamped,
        reason: '--no-stamp defers creating hashes, it does not remove them',
      );
    });

    test('unstamped entries are not reported stale', () async {
      // An unstamped translation is "not yet tracked", not "out of date" —
      // otherwise the authoring pass would trade a big diff for a red check.
      seed();
      expect(await runCheck(['--fix', '--no-stamp']), 0);
      expect(await runCheck(['--strict']), 0);
    });

    test('--no-stamp without --fix is inert (read-only check)', () async {
      // The command prints a note in this case; what must hold structurally
      // is that a read-only check stays read-only.
      seed();
      final before = viText();

      expect(await runCheck(['--no-stamp']), 0);

      expect(viText(), before, reason: 'check without --fix never writes');
    });
  });
}
