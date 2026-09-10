@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `--list-acks` exists because [applyAcks] cannot report on an ack whose
/// warning has stopped firing: it walks the issue list, so an entry with no
/// issue is unreachable from there. Every case below is one of those.
void main() {
  group('dialect check --list-acks', () {
    late Directory tmp;

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    /// A project whose `vi` keeps the English verbatim, so `source_equality`
    /// fires. That rule fingerprints the **source**, which is what lets the
    /// two halves below be varied independently.
    void writeProject({String source = 'Email', String vi = 'Email'}) {
      tmp = Directory.systemTemp.createTempSync('dialect_listack_');
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

    void rewriteSource(String value) {
      File(p.join(tmp.path, 'dialect', 'source', 'en.arb')).writeAsStringSync(
        '''
{
  "@@locale": "en",
  "settingsEmailLabel": "$value",
  "@settingsEmailLabel": { "namespace": "settings", "description": "Email label." }
}
''',
      );
    }

    void rewriteTranslation(String value) {
      File(
        p.join(tmp.path, 'dialect', 'translations', 'vi.arb'),
      ).writeAsStringSync(
        '{ "@@locale": "vi", "settingsEmailLabel": "$value" }',
      );
    }

    Future<int> run(List<String> args) async =>
        await DialectCommandRunner().run(['check', ...args, tmp.path]) ?? 0;

    File stateFile() => File(p.join(tmp.path, '.dialect', 'state.json'));

    const ackId = 'source_equality:vi:settingsEmailLabel';

    test('an empty ledger says so', () async {
      writeProject();
      expect(await run(['--list-acks']), 0);
    });

    test('classifies a suppressing ack as live', () async {
      writeProject();
      await run(['--ack', ackId]);
      final out = await _capture(() => run(['--list-acks']));
      expect(out, contains('live'));
      expect(out, contains(ackId));
      expect(out, contains('1 live'));
    });

    test('an ack whose warning stopped firing is inert, not live', () async {
      writeProject();
      await run(['--ack', ackId]);
      // Translate it properly: the warning goes away, but the source this
      // ruling was made about is unchanged, so the ruling still holds.
      rewriteTranslation('Thư điện tử');
      final out = await _capture(() => run(['--list-acks']));
      expect(out, contains('inert'));
      expect(out, contains('1 inert'));
      expect(out, isNot(contains('1 live')));
    });

    test(
      'an ack lapses invisibly when the source moves and the rule goes quiet',
      () async {
        // The reported case: twelve entries reading like live rulings, whose
        // fingerprints had stopped matching and whose warnings no longer
        // fired. A normal run cannot see either fact.
        writeProject();
        await run(['--ack', ackId]);
        rewriteSource('Email address');
        expect(
          await run(['--strict']),
          0,
          reason: 'nothing fires, so a normal run reports nothing at all',
        );
        final out = await _capture(() => run(['--list-acks']));
        expect(out, contains('lapsed'));
        expect(out, contains('1 lapsed'));
        expect(out, contains('no longer adjudicate anything'));
      },
    );

    test('a deleted key leaves an orphaned ack', () async {
      writeProject();
      await run(['--ack', ackId]);
      File(
        p.join(tmp.path, 'dialect', 'source', 'en.arb'),
      ).writeAsStringSync('{ "@@locale": "en" }');
      final out = await _capture(() => run(['--list-acks']));
      expect(out, contains('orphaned'));
    });

    test('a hand-written id for an unknown rule is invalid', () async {
      writeProject();
      await run(['--ack', ackId]);
      final raw = stateFile().readAsStringSync();
      stateFile().writeAsStringSync(
        raw.replaceFirst('source_equality:', 'invented_rule:'),
      );
      final out = await _capture(() => run(['--list-acks']));
      expect(out, contains('invalid'));
    });

    group('--prune-acks', () {
      test('deletes a lapsed entry', () async {
        writeProject();
        await run(['--ack', ackId]);
        rewriteSource('Email address');
        expect(await run(['--prune-acks']), 0);
        expect(stateFile().readAsStringSync(), isNot(contains(ackId)));
      });

      test('keeps an inert entry, whose fingerprint still matches', () async {
        // Inert is a ruling that is still true of the current text. Pruning
        // it would throw away a judgement someone actually made.
        writeProject();
        await run(['--ack', ackId]);
        rewriteTranslation('Thư điện tử');
        expect(await run(['--prune-acks']), 0);
        expect(stateFile().readAsStringSync(), contains(ackId));
      });

      test('keeps a live entry', () async {
        writeProject();
        await run(['--ack', ackId]);
        expect(await run(['--prune-acks']), 0);
        expect(stateFile().readAsStringSync(), contains(ackId));
        expect(await run(['--strict']), 0);
      });
    });
  });
}

/// Run [body], capturing everything it writes to stdout.
Future<String> _capture(Future<int> Function() body) async {
  final sink = StringBuffer();
  await IOOverrides.runZoned(body, stdout: () => _CapturingStdout(sink));
  return sink.toString();
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
