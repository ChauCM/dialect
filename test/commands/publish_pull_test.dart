@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect publish / pull (local target)', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('dialect_pub_'));
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    void writeProject({String format = 'icu-json'}) {
      final d = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(d.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [es]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common]

publish:
  staging:
    target: local
    path: dist/locales/
    format: $format
    namespaces: [common]
    output: api/locales/
''');
      Directory(p.join(d.path, 'source')).createSync();
      File(p.join(d.path, 'source', 'en.arb')).writeAsStringSync(
        '{ "@@locale": "en", "commonCancel": "Cancel", '
        '"@commonCancel": { "namespace": "common", "description": "c" } }',
      );
      Directory(p.join(d.path, 'translations')).createSync();
      File(
        p.join(d.path, 'translations', 'es.arb'),
      ).writeAsStringSync('{ "@@locale": "es", "commonCancel": "Cancelar" }');
    }

    Future<int> run(List<String> args) async =>
        await DialectCommandRunner().run(args) ?? 0;

    String baseDir() => p.join(tmp.path, 'dist', 'locales');

    test(
      'publish writes head + immutable version dir; pull round-trips',
      () async {
        writeProject();
        expect(await run(['publish', 'staging', tmp.path]), 0);

        final head = File(p.join(baseDir(), 'manifest.json'));
        expect(head.existsSync(), isTrue);
        expect(head.readAsStringSync(), contains('"current"'));

        // Pull writes the per-locale JSON into the configured output dir.
        expect(await run(['pull', 'staging', tmp.path]), 0);
        final pulled = File(p.join(tmp.path, 'api', 'locales', 'es.json'));
        expect(pulled.existsSync(), isTrue);
        expect(
          pulled.readAsStringSync(),
          contains('"commonCancel": "Cancelar"'),
        );
      },
    );

    test('re-publishing identical content is idempotent', () async {
      writeProject();
      await run(['publish', 'staging', tmp.path]);
      final headBefore = File(
        p.join(baseDir(), 'manifest.json'),
      ).readAsStringSync();

      expect(await run(['publish', 'staging', tmp.path]), 0);
      // Same version → same head, no new version dirs.
      expect(
        File(p.join(baseDir(), 'manifest.json')).readAsStringSync(),
        headBefore,
      );
      final versionDirs = Directory(p.join(baseDir(), 'b')).listSync();
      expect(versionDirs, hasLength(1));
    });

    test('changing a source string publishes a new version', () async {
      writeProject();
      await run(['publish', 'staging', tmp.path]);
      File(p.join(tmp.path, 'dialect', 'source', 'en.arb')).writeAsStringSync(
        '{ "@@locale": "en", "commonCancel": "Dismiss", '
        '"@commonCancel": { "namespace": "common", "description": "c" } }',
      );
      expect(await run(['publish', 'staging', tmp.path]), 0);
      // Two immutable versions now exist; head points at the newer one.
      expect(Directory(p.join(baseDir(), 'b')).listSync(), hasLength(2));
    });

    test('pull aborts on a corrupted locale file (integrity check)', () async {
      writeProject();
      await run(['publish', 'staging', tmp.path]);
      // Corrupt the published es.json so its bytes no longer match the
      // manifest sha256.
      final versionDir = Directory(
        p.join(baseDir(), 'b'),
      ).listSync().first.path;
      File(p.join(versionDir, 'es.json')).writeAsStringSync('{"tampered":"x"}');

      expect(
        await run(['pull', 'staging', tmp.path]),
        65,
        reason: 'a sha256 mismatch must fail the pull, not ship corrupt data',
      );
    });

    test('--dry-run builds but writes nothing', () async {
      writeProject();
      expect(await run(['publish', 'staging', '--dry-run', tmp.path]), 0);
      expect(Directory(baseDir()).existsSync(), isFalse);
    });

    test('unknown env errors with exit 64', () async {
      writeProject();
      expect(await run(['publish', 'nope', tmp.path]), 64);
    });

    test('s3 target is not built yet (clear exit, no crash)', () async {
      final d = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(d.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: []
publish:
  prod:
    target: s3
    bucket: my-bucket
    output: api/locales/
''');
      Directory(p.join(d.path, 'source')).createSync();
      File(p.join(d.path, 'source', 'en.arb')).writeAsStringSync(
        '{ "@@locale": "en", "k": "v", "@k": { "namespace": "common" } }',
      );
      Directory(p.join(d.path, 'translations')).createSync();
      expect(await run(['publish', 'prod', tmp.path]), 70);
    });
  });
}
