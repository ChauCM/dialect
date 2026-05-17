import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/missing_keys.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('MissingKeysRule', () {
    test('flags keys in source absent from a translation', () {
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'a', value: 'A'),
            ArbEntry(key: 'b', value: 'B'),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'a', value: 'A-es')],
          ),
        },
      );
      final issues = const MissingKeysRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.key, 'b');
      expect(issues.first.locale, 'es');
      expect(issues.first.severity, IssueSeverity.error);
      expect(issues.first.hint, contains('dialect translate'));
    });

    test('passes when every locale covers every source key', () {
      final p = project(
        targetLocales: ['es', 'ja'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'a', value: 'A')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'a', value: 'A-es')],
          ),
          'ja': arb(
            locale: 'ja',
            entries: [ArbEntry(key: 'a', value: 'A-ja')],
          ),
        },
      );
      expect(const MissingKeysRule().run(p), isEmpty);
    });

    test('does not fire on extra keys in a translation', () {
      // Extra keys are a different problem; missing_keys is strictly
      // about source → translation coverage.
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'a', value: 'A')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(key: 'a', value: 'A-es'),
              ArbEntry(key: 'bonus', value: 'extra'),
            ],
          ),
        },
      );
      expect(const MissingKeysRule().run(p), isEmpty);
    });
  });
}
