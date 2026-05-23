import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/structural/key_format.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('KeyFormatRule', () {
    test('accepts flat camelCase keys', () {
      final p = project(
        targetLocales: const [],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'checkoutBookNow',
              value: 'Book Now',
              metadata: ArbMetadata(namespace: 'checkout'),
            ),
            ArbEntry(
              key: 'commonOk',
              value: 'OK',
              metadata: ArbMetadata(namespace: 'common'),
            ),
          ],
        ),
      );
      expect(const KeyFormatRule().run(p), isEmpty);
    });

    test('rejects dotted (pre-1.0) keys', () {
      final p = project(
        targetLocales: const [],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'checkout.bookNow', value: 'Book Now'),
          ],
        ),
      );
      final issues = const KeyFormatRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.key, 'checkout.bookNow');
      // Hint suggests the flat shape + namespace metadata.
      expect(issues.first.hint, contains('checkoutBookNow'));
      expect(issues.first.hint, contains('namespace'));
    });

    test('rejects keys with dashes or starting with a digit', () {
      final p = project(
        targetLocales: const [],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'kebab-case-key', value: 'a'),
            ArbEntry(key: '1startsWithDigit', value: 'b'),
          ],
        ),
      );
      final issues = const KeyFormatRule().run(p);
      expect(issues.map((i) => i.key), [
        'kebab-case-key',
        '1startsWithDigit',
      ]);
    });

    test('underscore-only keys are allowed (valid Dart)', () {
      final p = project(
        targetLocales: const [],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: '_internal',
              value: 'kept',
              metadata: ArbMetadata(namespace: 'common'),
            ),
          ],
        ),
      );
      expect(const KeyFormatRule().run(p), isEmpty);
    });
  });
}
