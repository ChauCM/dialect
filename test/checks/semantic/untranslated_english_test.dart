import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/semantic/untranslated_english.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('UntranslatedEnglishRule', () {
    test('warns on a clearly English word in a translation', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'home.subtitle', value: 'Explore new places'),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(
                key: 'home.subtitle',
                // "the" leaked in
                value: 'Explora the nuevos lugares',
              ),
            ],
          ),
        },
      );
      final issues = const UntranslatedEnglishRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('"the"'));
    });

    test('does not warn on a clean Spanish translation', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'home.subtitle', value: 'Explore new places'),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(key: 'home.subtitle', value: 'Explora nuevos lugares'),
            ],
          ),
        },
      );
      expect(const UntranslatedEnglishRule().run(p), isEmpty);
    });

    test('carryover guard: skip when source value also contains the word', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'home.brand',
              value: 'Subscribe to the New York Times',
            ),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(
                key: 'home.brand',
                value: 'Suscríbete a the New York Times',
              ),
            ],
          ),
        },
      );
      expect(const UntranslatedEnglishRule().run(p), isEmpty);
    });

    test('reports at most one issue per entry', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'home.title', value: 'Find your next stay')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(
                key: 'home.title',
                // Several English words — only one issue should fire.
                value: 'Encuentra the and with',
              ),
            ],
          ),
        },
      );
      expect(const UntranslatedEnglishRule().run(p), hasLength(1));
    });

    test('skips the source locale itself', () {
      final p = project(
        targetLocales: const ['en'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'home.title', value: 'Find your next stay')],
        ),
        translations: {
          'en': arb(
            locale: 'en',
            entries: [
              ArbEntry(key: 'home.title', value: 'Find your next stay'),
            ],
          ),
        },
      );
      expect(const UntranslatedEnglishRule().run(p), isEmpty);
    });
  });
}
