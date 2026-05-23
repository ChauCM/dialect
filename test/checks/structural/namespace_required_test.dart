import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/structural/namespace_required.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('NamespaceRequiredRule', () {
    test('accepts source keys with @key.namespace', () {
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
          ],
        ),
      );
      expect(const NamespaceRequiredRule().run(p), isEmpty);
    });

    test('flags source keys without namespace metadata', () {
      final p = project(
        targetLocales: const [],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'unnamespacedKey', value: 'value'),
          ],
        ),
      );
      final issues = const NamespaceRequiredRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.key, 'unnamespacedKey');
      expect(issues.first.hint, contains('namespace'));
    });

    test('empty namespace string counts as missing', () {
      final p = project(
        targetLocales: const [],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'k',
              value: 'v',
              metadata: ArbMetadata(namespace: ''),
            ),
          ],
        ),
      );
      expect(const NamespaceRequiredRule().run(p), hasLength(1));
    });

    test('does not look at translation ARBs', () {
      // Translations don't carry @key metadata in our convention; the
      // rule is source-only by design.
      final p = project(
        targetLocales: ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'commonOk',
              value: 'OK',
              metadata: ArbMetadata(namespace: 'common'),
            ),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'commonOk', value: 'Vale')],
          ),
        },
      );
      expect(const NamespaceRequiredRule().run(p), isEmpty);
    });
  });
}
