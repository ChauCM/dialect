@TestOn('vm')
library;

import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/config/dialect_config.dart';
import 'package:dialect/project/dialect_project.dart';
import 'package:dialect/templates/plan_render.dart';
import 'package:test/test.dart';

void main() {
  group('renderPlanTemplate', () {
    test('substitutes every matching {{TOKEN}}', () {
      final out = renderPlanTemplate(
        'project={{PROJECT_NAME}}, src={{SOURCE_LOCALE}}',
        {'PROJECT_NAME': 'Demo', 'SOURCE_LOCALE': 'en'},
      );
      expect(out, 'project=Demo, src=en');
    });

    test('replaces every occurrence of a repeated token', () {
      final out = renderPlanTemplate('{{X}} and {{X}} and {{X}}', {'X': 'hi'});
      expect(out, 'hi and hi and hi');
    });

    test('leaves unknown tokens untouched so typos are loud', () {
      final out = renderPlanTemplate(
        'known={{KNOWN}}, unknown={{NOT_A_TOKEN}}',
        {'KNOWN': 'yes'},
      );
      expect(out, 'known=yes, unknown={{NOT_A_TOKEN}}');
    });
  });

  group('commonPlanTokens', () {
    test('pulls source/target locales from config', () {
      final p = _project(targetLocales: const ['es', 'ja', 'ar']);
      final tokens = commonPlanTokens(p);
      expect(tokens['SOURCE_LOCALE'], 'en');
      expect(tokens['TARGET_LOCALES'], 'es, ja, ar');
    });

    test('TARGET_LOCALES degrades gracefully when none configured', () {
      final p = _project(targetLocales: const []);
      expect(commonPlanTokens(p)['TARGET_LOCALES'], '(none configured yet)');
    });

    test('PROJECT_NAME falls back to the canonical placeholder', () {
      final p = _project();
      expect(commonPlanTokens(p)['PROJECT_NAME'], 'Your project');
    });

    test('PROJECT_NAME reads project.name from extras when set', () {
      final p = _project(
        extras: const {
          'project': {'name': 'Acme Travel'},
        },
      );
      expect(commonPlanTokens(p)['PROJECT_NAME'], 'Acme Travel');
    });

    test('NAMESPACES is the sorted union across platforms', () {
      final p = _project(
        platforms: {
          'flutter': PlatformConfig(
            name: 'flutter',
            output: 'lib/l10n/',
            format: 'arb',
            namespaces: const ['common', 'checkout'],
          ),
          'backend': PlatformConfig(
            name: 'backend',
            output: 'api/locales/',
            format: 'flat-json',
            namespaces: const ['common', 'settings'],
          ),
        },
      );
      expect(commonPlanTokens(p)['NAMESPACES'], 'checkout, common, settings');
    });

    test('GENERATED_AT is an ISO8601 UTC string', () {
      final p = _project();
      final tokens = commonPlanTokens(p);
      final ts = tokens['GENERATED_AT']!;
      expect(ts, endsWith('Z'));
      // Parses without throwing.
      expect(DateTime.parse(ts), isA<DateTime>());
    });
  });
}

DialectProject _project({
  List<String> targetLocales = const [],
  Map<String, PlatformConfig> platforms = const {},
  Map<String, Object?> extras = const {},
}) {
  return DialectProject(
    root: '<test>',
    config: DialectConfig(
      sourceLocale: 'en',
      targetLocales: targetLocales,
      platforms: platforms,
      extras: extras,
    ),
    source: ArbFile(locale: 'en', entries: const []),
    translations: const {},
  );
}
