@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dialect/arb/arb_writer.dart';
import 'package:dialect/server/server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('buildHandler', () {
    test('GET /api/config returns parsed dialect.yaml', () async {
      final root = _scratchProject();
      addTearDown(() => _cleanup(root));
      final handler = buildHandler(root);

      final res = await handler(_get('/api/config'));
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, Object?>;
      expect(body['source_locale'], 'en');
      expect(body['target_locales'], ['es', 'ja']);
      expect(body['project_name'], 'Demo');
    });

    test('GET /api/strings?locale=es lists every source key', () async {
      final root = _scratchProject(
        translations: {
          'es.arb': '{"@@locale":"es","common.cancel":"Cancelar"}',
        },
      );
      addTearDown(() => _cleanup(root));

      final res = await buildHandler(root)(_get('/api/strings?locale=es'));
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, Object?>;
      expect(body['locale'], 'es');
      final entries = body['entries'] as List;
      expect(entries, hasLength(2));
      final cancel =
          entries.firstWhere((e) => (e as Map)['key'] == 'common.cancel')
              as Map<String, Object?>;
      expect(cancel['translation'], 'Cancelar');
      expect(cancel['missing'], false);
      final book =
          entries.firstWhere((e) => (e as Map)['key'] == 'checkout.bookNow')
              as Map<String, Object?>;
      expect(book['translation'], isNull);
      expect(book['missing'], true);
    });

    test('GET /api/strings rejects missing/unknown locales', () async {
      final root = _scratchProject();
      addTearDown(() => _cleanup(root));

      final missing = await buildHandler(root)(_get('/api/strings'));
      expect(missing.statusCode, 400);

      final unknown = await buildHandler(root)(_get('/api/strings?locale=zz'));
      expect(unknown.statusCode, 404);
    });

    test('PUT /api/strings/<key> writes back through ArbWriter', () async {
      final root = _scratchProject();
      addTearDown(() => _cleanup(root));

      final res = await buildHandler(root)(
        _put(
          '/api/strings/checkout.bookNow',
          body: {'locale': 'es', 'value': 'Reservar ahora'},
        ),
      );
      expect(res.statusCode, 200);

      // On-disk side-effect: es.arb now contains the new value.
      final esPath = p.join(root, 'dialect', 'translations', 'es.arb');
      final body = File(esPath).readAsStringSync();
      expect(body, contains('"checkout.bookNow": "Reservar ahora"'));
      // Source ARB untouched.
      final enPath = p.join(root, 'dialect', 'source', 'en.arb');
      expect(
        File(enPath).readAsStringSync(),
        contains('"checkout.bookNow": "Book Now"'),
      );
    });

    test('PUT with locked=true writes @key.source_hash', () async {
      final root = _scratchProject();
      addTearDown(() => _cleanup(root));

      final res = await buildHandler(root)(
        _put(
          '/api/strings/checkout.bookNow',
          body: {'locale': 'es', 'value': 'Reservar ahora', 'locked': true},
        ),
      );
      expect(res.statusCode, 200);

      final body = File(
        p.join(root, 'dialect', 'translations', 'es.arb'),
      ).readAsStringSync();
      expect(body, contains('"locked": true'));
      // SHA-256("Book Now")[0:16] = 67be79359de4aa3f per source_hash spec.
      expect(body, contains('"source_hash": "67be79359de4aa3f"'));
    });

    test('PUT with locked=false drops empty @key blocks entirely', () async {
      // Regression: an unlock should leave the file looking like a
      // freshly-translated entry with no metadata at all — not an
      // orphan `@key: {}` block.
      final root = _scratchProject(
        translations: {
          'es.arb':
              '{"@@locale":"es","checkout.bookNow":"Reservar","@checkout.bookNow":{"locked":true,"source_hash":"67be79359de4aa3f"}}',
        },
      );
      addTearDown(() => _cleanup(root));

      await buildHandler(root)(
        _put(
          '/api/strings/checkout.bookNow',
          body: {'locale': 'es', 'value': 'Reservar', 'locked': false},
        ),
      );
      final body = File(
        p.join(root, 'dialect', 'translations', 'es.arb'),
      ).readAsStringSync();
      expect(body.contains('@checkout.bookNow'), isFalse);
      expect(body.contains('{}'), isFalse);
    });

    test('PUT with locked=false clears source_hash', () async {
      final root = _scratchProject(
        translations: {
          'es.arb':
              '{"@@locale":"es","checkout.bookNow":"Reservar","@checkout.bookNow":{"locked":true,"source_hash":"67be79359de4aa3f"}}',
        },
      );
      addTearDown(() => _cleanup(root));

      final res = await buildHandler(root)(
        _put(
          '/api/strings/checkout.bookNow',
          body: {'locale': 'es', 'value': 'Reservar', 'locked': false},
        ),
      );
      expect(res.statusCode, 200);
      final body = File(
        p.join(root, 'dialect', 'translations', 'es.arb'),
      ).readAsStringSync();
      expect(body.contains('source_hash'), isFalse);
      expect(body.contains('"locked"'), isFalse);
    });

    test('PUT rejects malformed bodies with 400', () async {
      final root = _scratchProject();
      addTearDown(() => _cleanup(root));
      final handler = buildHandler(root);

      // Not JSON.
      expect(
        (await handler(_putRaw('/api/strings/x', 'not-json'))).statusCode,
        400,
      );
      // Missing locale.
      expect(
        (await handler(
          _put('/api/strings/x', body: {'value': 'v'}),
        )).statusCode,
        400,
      );
      // Missing value.
      expect(
        (await handler(
          _put('/api/strings/x', body: {'locale': 'es'}),
        )).statusCode,
        400,
      );
      // Unknown locale.
      expect(
        (await handler(
          _put(
            '/api/strings/checkout.bookNow',
            body: {'locale': 'zz', 'value': 'v'},
          ),
        )).statusCode,
        404,
      );
      // Unknown source key.
      expect(
        (await handler(
          _put('/api/strings/no.such', body: {'locale': 'es', 'value': 'v'}),
        )).statusCode,
        404,
      );
    });

    test('GET /api/glossary surfaces parsed terms', () async {
      final root = _scratchProject(
        glossary: '''
terms:
  - term: "Book"
    meaning: "Verb. Make a reservation."
    translations:
      es: "Reservar"
''',
      );
      addTearDown(() => _cleanup(root));

      final res = await buildHandler(root)(_get('/api/glossary'));
      final body = jsonDecode(await res.readAsString()) as Map<String, Object?>;
      final terms = body['terms'] as List;
      expect(terms, hasLength(1));
      expect((terms.first as Map)['term'], 'Book');
    });

    test('GET /api/status reuses the M6 computeStatus math', () async {
      final root = _scratchProject(
        translations: {
          'es.arb':
              '{"@@locale":"es","checkout.bookNow":"Reservar","common.cancel":"Cancelar"}',
          'ja.arb': '{"@@locale":"ja"}',
        },
      );
      addTearDown(() => _cleanup(root));

      final res = await buildHandler(root)(_get('/api/status'));
      final body = jsonDecode(await res.readAsString()) as Map<String, Object?>;
      final rows = body['rows'] as List;
      expect(rows, hasLength(2));
      final es = rows.firstWhere((r) => (r as Map)['locale'] == 'es') as Map;
      expect(es['coverage'], 1.0);
      final ja = rows.firstWhere((r) => (r as Map)['locale'] == 'ja') as Map;
      expect(ja['coverage'], 0.0);
      expect(ja['missing'], 2);
    });

    test(
      'unknown /api path returns 404 (router falls through to SPA but only for non-/api)',
      () async {
        final root = _scratchProject();
        addTearDown(() => _cleanup(root));
        final res = await buildHandler(root)(_get('/api/does-not-exist'));
        expect(res.statusCode, 404);
      },
    );

    test(
      'GET / returns the no-dashboard fallback when assets are empty',
      () async {
        // After `dart run tool/build_dashboard.dart`, embeddedAssets is
        // non-empty and `/` returns the baked-in index.html. On a
        // fresh checkout without the generator having run, it returns
        // a "not built yet" fallback. Either is a valid 200; the only
        // thing this test locks down is that `/` doesn't 404.
        final root = _scratchProject();
        addTearDown(() => _cleanup(root));
        final res = await buildHandler(root)(_get('/'));
        expect(res.statusCode, 200);
        final body = await res.readAsString();
        expect(
          body.contains('<!doctype html>') ||
              body.contains('Dashboard not bundled'),
          isTrue,
        );
      },
    );

    test('CORS preflight returns the right headers', () async {
      final root = _scratchProject();
      addTearDown(() => _cleanup(root));
      final res = await buildHandler(root)(
        Request('OPTIONS', Uri.parse('http://localhost/api/config')),
      );
      expect(res.statusCode, 200);
      expect(res.headers['access-control-allow-origin'], '*');
      expect(res.headers['access-control-allow-methods'], contains('PUT'));
    });
  });

  group('PUT idempotency', () {
    test('writing the same value twice does not change mtime', () async {
      final root = _scratchProject(
        translations: {
          'es.arb': '{"@@locale":"es","checkout.bookNow":"Reservar"}',
        },
      );
      addTearDown(() => _cleanup(root));
      final handler = buildHandler(root);
      final esPath = p.join(root, 'dialect', 'translations', 'es.arb');

      await handler(
        _put(
          '/api/strings/checkout.bookNow',
          body: {'locale': 'es', 'value': 'Reservar'},
        ),
      );
      final mtime1 = File(esPath).statSync().modified;

      await Future<void>.delayed(const Duration(milliseconds: 20));

      await handler(
        _put(
          '/api/strings/checkout.bookNow',
          body: {'locale': 'es', 'value': 'Reservar'},
        ),
      );
      final mtime2 = File(esPath).statSync().modified;
      expect(mtime2, mtime1, reason: 'no-op PUT must not touch the file');
    });
  });
}

Request _get(String path) => Request('GET', Uri.parse('http://localhost$path'));

Request _put(String path, {required Map<String, Object?> body}) {
  return Request(
    'PUT',
    Uri.parse('http://localhost$path'),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode(body),
  );
}

Request _putRaw(String path, String body) {
  return Request(
    'PUT',
    Uri.parse('http://localhost$path'),
    headers: const {'content-type': 'application/json'},
    body: body,
  );
}

String _scratchProject({
  Map<String, String> translations = const {},
  String? glossary,
}) {
  final tmp = Directory.systemTemp.createTempSync('dialect_serve_test_');
  final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
  File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: [es, ja]

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common, checkout]

project:
  name: Demo
''');
  final srcDir = Directory(p.join(dialectDir.path, 'source'))..createSync();
  File(p.join(srcDir.path, 'en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "checkout.bookNow": "Book Now",
  "@checkout.bookNow": {
    "description": "CTA on the checkout screen."
  },
  "common.cancel": "Cancel",
  "@common.cancel": {
    "description": "Generic cancel action."
  }
}
''');
  final tDir = Directory(p.join(dialectDir.path, 'translations'))..createSync();
  for (final entry in translations.entries) {
    File(p.join(tDir.path, entry.key)).writeAsStringSync(entry.value);
  }
  if (glossary != null) {
    File(p.join(dialectDir.path, 'glossary.yaml')).writeAsStringSync(glossary);
  }
  return tmp.path;
}

void _cleanup(String root) {
  final dir = Directory(root);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
}

// Silences the otherwise-unused ArbWriter import (kept for symmetry
// with the source code under test, and as a forward-reference signal
// that PUT round-trips through ArbWriter).
// ignore: unused_element
String _arbWriterReference() => ArbWriter.encode.toString();
