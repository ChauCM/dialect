@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end coverage for the change-half of the sync loop: provenance
/// stamping in `--fix`, the `stale_translation` check, and the lock-wipe
/// regression that the fixer change fixes.
void main() {
  group('stale tracking (integration)', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('dialect_stale_'));
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    void writeProject({required String source, required String es}) {
      final d = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(d.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [es]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common]
''');
      Directory(p.join(d.path, 'source')).createSync();
      File(p.join(d.path, 'source', 'en.arb')).writeAsStringSync(source);
      Directory(p.join(d.path, 'translations')).createSync();
      File(p.join(d.path, 'translations', 'es.arb')).writeAsStringSync(es);
    }

    Future<int> run(List<String> args) async =>
        await DialectCommandRunner().run(args) ?? 0;

    String esBody() => File(
      p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
    ).readAsStringSync();

    String sourceArb(String value) =>
        '{ "@@locale": "en", "commonCancel": "$value", '
        '"@commonCancel": { "namespace": "common", "description": "Cancel." } }';

    test(
      '--fix stamps provenance, then a source change makes it stale',
      () async {
        writeProject(
          source: sourceArb('Cancel'),
          es: '{ "@@locale": "es", "commonCancel": "Cancelar" }',
        );

        // 1. --fix stamps a source_hash onto the unlocked translation.
        expect(await run(['check', '--fix', tmp.path]), 0);
        expect(esBody(), contains('"source_hash"'));

        // 2. Clean while the source is unchanged.
        expect(await run(['check', '--strict', tmp.path]), 0);

        // 3. Change the English source → the stamped hash no longer matches.
        File(
          p.join(tmp.path, 'dialect', 'source', 'en.arb'),
        ).writeAsStringSync(sourceArb('Dismiss'));

        // 4. check flags it stale; --strict fails.
        expect(await run(['check', '--strict', tmp.path]), 1);
      },
    );

    test('re-translating (clearing the hash) refreshes via --fix', () async {
      writeProject(
        source: sourceArb('Cancel'),
        es: '{ "@@locale": "es", "commonCancel": "Cancelar" }',
      );
      await run(['check', '--fix', tmp.path]);
      File(
        p.join(tmp.path, 'dialect', 'source', 'en.arb'),
      ).writeAsStringSync(sourceArb('Dismiss'));
      expect(await run(['check', '--strict', tmp.path]), 1); // stale

      // Simulate the AI re-translating: new value, @key block deleted.
      File(
        p.join(tmp.path, 'dialect', 'translations', 'es.arb'),
      ).writeAsStringSync('{ "@@locale": "es", "commonCancel": "Descartar" }');

      // --fix re-stamps the current source hash → fresh again.
      expect(await run(['check', '--fix', tmp.path]), 0);
      expect(await run(['check', '--strict', tmp.path]), 0);
    });

    test('regression: --fix no longer wipes a lock + its hash', () async {
      // Before the fixer change, _stripMetadata rebuilt every translation
      // as bare key/value, silently destroying dashboard-written locks on
      // the next --fix. They must now survive.
      writeProject(
        source: sourceArb('Cancel'),
        es:
            '{ "@@locale": "es", "commonCancel": "Cancelar", '
            '"@commonCancel": { "locked": true, "source_hash": "abc1230000000000" } }',
      );
      expect(await run(['check', '--fix', tmp.path]), 0);
      final body = esBody();
      expect(
        body,
        contains('"locked": true'),
        reason: 'lock must survive --fix',
      );
      expect(
        body,
        contains('abc1230000000000'),
        reason: 'its hash must survive',
      );
    });
  });
}
