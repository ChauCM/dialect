import 'package:dialect/adapters/arb_adapter.dart';
import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/config/dialect_config.dart';
import 'package:test/test.dart';

void main() {
  group('ArbAdapter.prepare', () {
    final greet = ArbEntry(
      key: 'commonGreet',
      value: 'Hello',
      metadata: ArbMetadata(namespace: 'common', description: 'A greeting.'),
    );
    final book = ArbEntry(
      key: 'checkoutBookNow',
      value: 'Book Now',
      metadata: ArbMetadata(namespace: 'checkout', description: 'CTA.'),
    );
    final unnamespaced = ArbEntry(key: 'loose', value: 'no namespace');

    test('keeps source metadata, strips translation metadata', () {
      final source = ArbFile(locale: 'en', entries: [greet, book]);
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
      );

      final src = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: true,
      );
      expect(src.arb.entries.first.metadata, isNotNull);

      final trans = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: false,
        source: source,
      );
      expect(trans.arb.entries.first.metadata, isNull);
      expect(
        trans.arb.entries.length,
        source.entries.length,
        reason: 'stripping metadata does not drop entries',
      );
    });

    test('translation filter joins on source namespaces (regression: B3)', () {
      // Translation files carry no `@key` metadata by convention. Sync
      // used to read `entry.namespace` directly on translation entries,
      // get null for everything, and drop every key into the
      // "missing namespace" bucket. The fix: look up each key's
      // namespace via the source ARB.
      final source = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(
            key: 'commonGreet',
            value: 'Hello',
            metadata: ArbMetadata(namespace: 'common'),
          ),
          ArbEntry(
            key: 'checkoutBookNow',
            value: 'Book Now',
            metadata: ArbMetadata(namespace: 'checkout'),
          ),
        ],
      );
      final translation = ArbFile(
        locale: 'es',
        entries: [
          ArbEntry(key: 'commonGreet', value: 'Hola'),
          ArbEntry(key: 'checkoutBookNow', value: 'Reservar ahora'),
        ],
      );
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
        namespaces: ['common', 'checkout'],
      );

      final out = ArbAdapter.prepare(
        translation,
        platform: platform,
        isSource: false,
        source: source,
      );
      expect(
        out.arb.entries.map((e) => e.key),
        ['commonGreet', 'checkoutBookNow'],
        reason: 'both keys must pass; namespace comes from source ARB',
      );
      expect(out.keysMissingNamespace, isEmpty);
    });

    test(
      'translation key absent from source surfaces as missing namespace',
      () {
        // If a translation has a key that doesn't exist in source, we
        // can't resolve a namespace for it — drop it and report. This
        // is the same surface the user already sees for un-namespaced
        // source keys.
        final source = ArbFile(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'commonGreet',
              value: 'Hello',
              metadata: ArbMetadata(namespace: 'common'),
            ),
          ],
        );
        final translation = ArbFile(
          locale: 'es',
          entries: [
            ArbEntry(key: 'commonGreet', value: 'Hola'),
            ArbEntry(key: 'orphan', value: 'no source entry'),
          ],
        );
        final platform = PlatformConfig(
          name: 'flutter',
          output: 'lib/l10n',
          format: 'arb',
          namespaces: ['common'],
        );

        final out = ArbAdapter.prepare(
          translation,
          platform: platform,
          isSource: false,
          source: source,
        );
        expect(out.arb.entries.map((e) => e.key), ['commonGreet']);
        expect(out.keysMissingNamespace, ['orphan']);
      },
    );

    test('namespace filter drops keys outside the allowlist', () {
      final source = ArbFile(
        locale: 'en',
        entries: [greet, book, unnamespaced],
      );
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
        namespaces: ['common'],
      );
      final out = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: true,
      );
      expect(out.arb.entries.map((e) => e.key), ['commonGreet']);
    });

    test('empty namespaces list means no filtering', () {
      final source = ArbFile(
        locale: 'en',
        entries: [greet, book, unnamespaced],
      );
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
      );
      final out = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: true,
      );
      expect(out.arb.entries.map((e) => e.key), [
        'commonGreet',
        'checkoutBookNow',
        'loose',
      ]);
    });

    test('filter matches the metadata namespace, not the key prefix', () {
      // Two keys with namespace=checkout (regardless of their camelCase
      // shape) both pass when `namespaces: [checkout]`.
      final source = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(
            key: 'checkoutA',
            value: 'A',
            metadata: ArbMetadata(namespace: 'checkout'),
          ),
          ArbEntry(
            key: 'somethingElse',
            value: 'B',
            metadata: ArbMetadata(namespace: 'checkout'),
          ),
          ArbEntry(
            key: 'commonC',
            value: 'C',
            metadata: ArbMetadata(namespace: 'common'),
          ),
        ],
      );
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
        namespaces: ['checkout'],
      );
      final out = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: true,
      );
      expect(out.arb.entries.map((e) => e.key), ['checkoutA', 'somethingElse']);
    });

    test('reports keys missing @key.namespace metadata', () {
      final source = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(
            key: 'commonOk',
            value: 'OK',
            metadata: ArbMetadata(namespace: 'common'),
          ),
          ArbEntry(key: 'looseKey', value: 'no namespace'),
          ArbEntry(key: 'anotherLoose', value: 'still none'),
        ],
      );
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
        namespaces: ['common'],
      );
      final out = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: true,
      );
      expect(out.arb.entries.map((e) => e.key), ['commonOk']);
      expect(out.keysMissingNamespace, ['looseKey', 'anotherLoose']);
    });

    test('empty namespaces list does not flag missing namespace', () {
      // When filtering is off, everything passes; no warning needed.
      final source = ArbFile(
        locale: 'en',
        entries: [ArbEntry(key: 'looseKey', value: 'kept')],
      );
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
      );
      final out = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: true,
      );
      expect(out.keysMissingNamespace, isEmpty);
      expect(out.arb.entries.map((e) => e.key), ['looseKey']);
    });

    test('orphan metadata is dropped on output', () {
      final source = ArbFile(
        locale: 'en',
        entries: [greet],
        orphanMetadata: {
          'orphan': ArbMetadata(description: 'should not appear'),
        },
      );
      final platform = PlatformConfig(
        name: 'flutter',
        output: 'lib/l10n',
        format: 'arb',
      );
      final out = ArbAdapter.prepare(
        source,
        platform: platform,
        isSource: true,
      );
      expect(out.arb.orphanMetadata, isEmpty);
    });
  });

  group('ArbAdapter.filenameFor', () {
    test('uses the Flutter app_<locale>.arb convention', () {
      expect(ArbAdapter.filenameFor('en'), 'app_en.arb');
      expect(ArbAdapter.filenameFor('pt-BR'), 'app_pt-BR.arb');
    });
  });
}
