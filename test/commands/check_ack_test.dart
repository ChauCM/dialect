@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect check --ack', () {
    late Directory tmp;

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    // A project whose vi translation keeps "Email" verbatim → the
    // source_equality heuristic fires.
    void writeProject({String source = 'Email', String vi = 'Email'}) {
      tmp = Directory.systemTemp.createTempSync('dialect_ack_');
      final d = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(d.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [vi]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [settings]
''');
      Directory(p.join(d.path, 'source')).createSync();
      File(p.join(d.path, 'source', 'en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "settingsEmailLabel": "$source",
  "@settingsEmailLabel": { "namespace": "settings", "description": "Email label." }
}
''');
      Directory(p.join(d.path, 'translations')).createSync();
      File(
        p.join(d.path, 'translations', 'vi.arb'),
      ).writeAsStringSync('{ "@@locale": "vi", "settingsEmailLabel": "$vi" }');
    }

    Future<int> run(List<String> args) async =>
        await DialectCommandRunner().run(['check', ...args, tmp.path]) ?? 0;

    File stateFile() => File(p.join(tmp.path, '.dialect', 'state.json'));

    test('writes state.json and suppresses the warning on next run', () async {
      writeProject();

      // Ack the source_equality warning.
      expect(await run(['--ack', 'source_equality:vi:settingsEmailLabel']), 0);
      expect(stateFile().existsSync(), isTrue);
      expect(
        stateFile().readAsStringSync(),
        contains('source_equality:vi:settingsEmailLabel'),
      );

      // A subsequent --strict run must pass: the only warning is acked.
      expect(await run(['--strict']), 0);
    });

    test('drifted value re-fires the warning and flags a stale ack', () async {
      writeProject();
      await run(['--ack', 'source_equality:vi:settingsEmailLabel']);

      // Change both source and translation to a new identical value: the
      // warning fires again, but the stored fingerprint no longer matches.
      File(p.join(tmp.path, 'dialect', 'source', 'en.arb')).writeAsStringSync(
        '''
{
  "@@locale": "en",
  "settingsEmailLabel": "Mail",
  "@settingsEmailLabel": { "namespace": "settings", "description": "Email label." }
}
''',
      );
      File(
        p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
      ).writeAsStringSync('{ "@@locale": "vi", "settingsEmailLabel": "Mail" }');

      // --strict now fails because the ack is stale and the warning is back.
      expect(await run(['--strict']), 1);
    });

    test('rejects acking a structural rule', () async {
      writeProject();
      expect(await run(['--ack', 'missing_keys:vi:settingsEmailLabel']), 64);
      expect(stateFile().existsSync(), isFalse);
    });

    test('rejects a malformed ack id', () async {
      writeProject();
      expect(await run(['--ack', 'not-a-valid-id']), 64);
    });

    test('errors when the key cannot be resolved', () async {
      writeProject();
      expect(await run(['--ack', 'source_equality:vi:doesNotExist']), 65);
    });
  });
}
