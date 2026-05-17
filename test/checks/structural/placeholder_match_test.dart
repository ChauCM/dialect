import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/placeholder_match.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('PlaceholderMatchRule', () {
    test('flags dropped placeholder', () {
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'greet',
              value: 'Hello {name}, you have {count} items',
            ),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(key: 'greet', value: 'Hola, tienes {count} artículos'),
              // Dropped {name}
            ],
          ),
        },
      );
      final issues = const PlaceholderMatchRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('{name}'));
      expect(issues.first.severity, IssueSeverity.error);
      expect(issues.first.hint, contains('byte-identical'));
    });

    test('flags introduced placeholder', () {
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'greet', value: 'Hello {name}')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'greet', value: 'Hola {name} ({count})')],
          ),
        },
      );
      final issues = const PlaceholderMatchRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('{count}'));
      expect(issues.first.message, contains('unexpected'));
    });

    test('passes when source and translation use the same placeholders', () {
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'greet',
              value: 'Hello {name}, you have {count} items',
            ),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(
                key: 'greet',
                value: 'Hola {name}, tienes {count} artículos',
              ),
            ],
          ),
        },
      );
      expect(const PlaceholderMatchRule().run(p), isEmpty);
    });

    test('passes when neither side has placeholders', () {
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'k', value: 'plain string')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'k', value: 'cadena simple')],
          ),
        },
      );
      expect(const PlaceholderMatchRule().run(p), isEmpty);
    });

    test(
      'ignores keys missing from the translation (covered by missing_keys)',
      () {
        final p = project(
          targetLocales: ['es'],
          source: arb(
            locale: 'en',
            entries: [ArbEntry(key: 'greet', value: 'Hello {name}')],
          ),
          translations: {'es': arb(locale: 'es', entries: const [])},
        );
        expect(const PlaceholderMatchRule().run(p), isEmpty);
      },
    );
  });
}
