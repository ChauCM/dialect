import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/structural/empty_values.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('EmptyValuesRule', () {
    test('flags empty source values', () {
      final p = project(
        targetLocales: const [],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'k', value: '')],
        ),
      );
      final issues = const EmptyValuesRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.key, 'k');
      expect(issues.first.locale, isNull, reason: 'source-side issue');
    });

    test('flags empty translation values', () {
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'k', value: 'something')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'k', value: '')],
          ),
        },
      );
      final issues = const EmptyValuesRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.locale, 'es');
    });

    test('passes on a fully-populated project', () {
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'k', value: 'A')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'k', value: 'A-es')],
          ),
        },
      );
      expect(const EmptyValuesRule().run(p), isEmpty);
    });
  });
}
