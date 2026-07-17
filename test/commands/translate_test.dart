@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dialect translate', () {
    late Directory tmp;

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    String planBody() => File(
      p.join(tmp.path, '.dialect', 'translate-plan.md'),
    ).readAsStringSync();

    test('lists missing keys per locale in source order', () async {
      tmp = _project(
        source: '''
{
  "@@locale": "en",
  "checkoutBookNow": "Book Now",
  "@checkoutBookNow": { "namespace": "checkout", "description": "CTA." },
  "commonCancel": "Cancel",
  "@commonCancel": { "namespace": "common", "description": "Cancel." },
  "commonLoading": "Loading...",
  "@commonLoading": { "namespace": "common", "description": "Spinner." }
}
''',
        translations: {
          'es': '{ "@@locale": "es", "commonCancel": "Cancelar" }',
        },
      );

      final exit = await DialectCommandRunner().run(['translate', tmp.path]);
      expect(exit, 0);

      final body = planBody();
      // Tokens resolved.
      expect(body, isNot(contains('{{WORKLIST}}')));
      expect(body, isNot(contains('{{SOURCE_LOCALE}}')));
      // Both missing keys appear, in source order (Book before Loading).
      expect(body, contains('### `es`'));
      expect(body, contains('- `checkoutBookNow`'));
      expect(body, contains('- `commonLoading`'));
      expect(
        body.indexOf('checkoutBookNow'),
        lessThan(body.indexOf('commonLoading')),
      );
      // commonCancel is already translated — not listed as missing.
      expect(body, contains('Missing (2)'));
    });

    test('flags stale locked keys for review, not translation', () async {
      tmp = _project(
        source: '''
{
  "@@locale": "en",
  "checkoutBookNow": "Book Now",
  "@checkoutBookNow": { "namespace": "checkout", "description": "CTA." }
}
''',
        translations: {
          // Locked with a hash that cannot match "Book Now" → stale.
          'ja':
              '{ "@@locale": "ja", "checkoutBookNow": "予約", "@checkoutBookNow": { "locked": true, "source_hash": "0000000000000000" } }',
        },
        targetLocales: ['ja'],
      );

      final exit = await DialectCommandRunner().run(['translate', tmp.path]);
      expect(exit, 0);

      final body = planBody();
      expect(body, contains('Stale (locked) (1)'));
      expect(body, contains('review only, do NOT edit'));
      // The locked key must NOT be listed as a missing-key bucket. (The
      // static instructions further down legitimately use the word
      // "Missing"; the worklist bucket header is "Missing (N)".)
      expect(body, isNot(contains('Missing (')));
    });

    test('unlocked stale key lands in the re-translate bucket', () async {
      tmp = _project(
        source: '''
{
  "@@locale": "en",
  "commonCancel": "Cancel",
  "@commonCancel": { "namespace": "common", "description": "Cancel." }
}
''',
        translations: {
          // Unlocked, with a hash that can't match "Cancel" → stale.
          'es':
              '{ "@@locale": "es", "commonCancel": "Cancelar", "@commonCancel": { "source_hash": "0000000000000000" } }',
        },
        targetLocales: ['es'],
      );

      final exit = await DialectCommandRunner().run(['translate', tmp.path]);
      expect(exit, 0);

      final body = planBody();
      // The unlocked-stale worklist bucket (header carries the count). The
      // static instructions further down legitimately name every bucket;
      // assert on the "(N)" count-header form to target the worklist.
      expect(body, contains('**Stale (1)'));
      expect(body, isNot(contains('Stale (locked) (')));
      expect(body, isNot(contains('Missing (')));
    });

    test('inlines source string, description, and glossary terms', () async {
      tmp = _project(
        source: '''
{
  "@@locale": "en",
  "journeyContinue": "Continue your journey",
  "@journeyContinue": {
    "namespace": "common",
    "description": "Button that reopens an achieved journey."
  }
}
''',
        translations: const {},
        targetLocales: ['vi'],
        glossary: '''
terms:
  - term: journey
    meaning: The user's ongoing achievement thread.
    translations:
      vi: hành trình
''',
      );

      final exit = await DialectCommandRunner().run(['translate', tmp.path]);
      expect(exit, 0);

      final body = planBody();
      expect(body, contains('- `journeyContinue`'));
      // Source string inlined — no need to re-open the ARB.
      expect(body, contains('source: "Continue your journey"'));
      // Description inlined.
      expect(
        body,
        contains('description: Button that reopens an achieved journey.'),
      );
      // Glossary term detected in the source, with its vi form.
      expect(body, contains('glossary: journey → hành trình'));
    });

    test(
      'does not surface a glossary term that is only a placeholder (#6)',
      () async {
        tmp = _project(
          source: '''
{
  "@@locale": "en",
  "stepDetailCrumb": "Step · {journey}",
  "@stepDetailCrumb": {
    "namespace": "common",
    "description": "Breadcrumb above a step.",
    "placeholders": { "journey": { "type": "String" } }
  }
}
''',
          translations: const {},
          targetLocales: ['vi'],
          glossary: '''
terms:
  - term: journey
    meaning: The user's ongoing achievement thread.
    translations:
      vi: hành trình
''',
        );

        final exit = await DialectCommandRunner().run(['translate', tmp.path]);
        expect(exit, 0);

        final body = planBody();
        expect(body, contains('- `stepDetailCrumb`'));
        // `{journey}` is a placeholder name, not copy — no glossary line.
        expect(body, isNot(contains('glossary:')));
      },
    );

    test('fully covered project reports nothing to do', () async {
      tmp = _project(
        source: '''
{
  "@@locale": "en",
  "commonCancel": "Cancel",
  "@commonCancel": { "namespace": "common", "description": "Cancel." }
}
''',
        translations: {
          'es': '{ "@@locale": "es", "commonCancel": "Cancelar" }',
        },
        targetLocales: ['es'],
      );

      final exit = await DialectCommandRunner().run(['translate', tmp.path]);
      expect(exit, 0);
      final body = planBody();
      expect(body, contains('nothing to do'));
    });

    test('--auto fails loudly (direct-LLM path not built yet)', () async {
      tmp = _project(
        source:
            '{ "@@locale": "en", "commonCancel": "Cancel", '
            '"@commonCancel": { "namespace": "common" } }',
        translations: const {},
        targetLocales: ['es'],
      );
      final exit = await DialectCommandRunner().run([
        'translate',
        '--auto',
        '--provider',
        'anthropic',
        tmp.path,
      ]);
      expect(exit, 70);
    });

    test('exits 66 when run outside a project', () async {
      tmp = Directory.systemTemp.createTempSync('dialect_translate_no_proj_');
      final exit = await DialectCommandRunner().run(['translate', tmp.path]);
      expect(exit, 66);
    });

    test('no target_locales configured exits 0 with a hint', () async {
      tmp = _project(
        source: '{ "@@locale": "en", "k": "v" }',
        translations: const {},
        targetLocales: const [],
      );
      final exit = await DialectCommandRunner().run(['translate', tmp.path]);
      expect(exit, 0);
    });
  });
}

Directory _project({
  required String source,
  required Map<String, String> translations,
  List<String> targetLocales = const ['es', 'ja'],
  String? glossary,
}) {
  final tmp = Directory.systemTemp.createTempSync('dialect_translate_');
  final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
  final tl = targetLocales.isEmpty ? '[]' : '[${targetLocales.join(', ')}]';
  File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync('''
source_locale: en
target_locales: $tl

platforms:
  flutter:
    output: lib/l10n/
    format: arb
    namespaces: [common, checkout]
''');
  Directory(p.join(dialectDir.path, 'source')).createSync();
  File(p.join(dialectDir.path, 'source', 'en.arb')).writeAsStringSync(source);
  if (glossary != null) {
    File(p.join(dialectDir.path, 'glossary.yaml')).writeAsStringSync(glossary);
  }
  final tDir = Directory(p.join(dialectDir.path, 'translations'))..createSync();
  for (final e in translations.entries) {
    File(p.join(tDir.path, '${e.key}.arb')).writeAsStringSync(e.value);
  }
  return tmp;
}
