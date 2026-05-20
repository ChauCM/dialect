import 'package:dialect/adapters/arb_adapter.dart';
import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/config/dialect_config.dart';
import 'package:test/test.dart';

void main() {
  group('ArbAdapter.prepare', () {
    final greet = ArbEntry(
      key: 'common.greet',
      value: 'Hello',
      metadata: ArbMetadata(description: 'A greeting.'),
    );
    final book = ArbEntry(
      key: 'checkout.bookNow',
      value: 'Book Now',
      metadata: ArbMetadata(description: 'CTA.'),
    );
    final loose = ArbEntry(key: 'bare', value: 'no namespace');

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
      );
      expect(trans.arb.entries.first.metadata, isNull);
      expect(
        trans.arb.entries.length,
        source.entries.length,
        reason: 'stripping metadata does not drop entries',
      );
    });

    test('namespace filter drops keys outside the allowlist', () {
      final source = ArbFile(locale: 'en', entries: [greet, book, loose]);
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
      expect(out.arb.entries.map((e) => e.key), ['common.greet']);
    });

    test('empty namespaces list means no filtering', () {
      final source = ArbFile(locale: 'en', entries: [greet, book, loose]);
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
        'common.greet',
        'checkout.bookNow',
        'bare',
      ]);
    });

    test('namespace-prefixed keys are filtered by their prefix only', () {
      // checkout.foo, checkout.bar both have prefix `checkout`; both
      // match `namespaces: [checkout]`.
      final source = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(key: 'checkout.a', value: 'A'),
          ArbEntry(key: 'checkout.b', value: 'B'),
          ArbEntry(key: 'common.c', value: 'C'),
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
      expect(out.arb.entries.map((e) => e.key), ['checkout.a', 'checkout.b']);
    });

    test('reports bare-namespace keys via bareKeysSkipped', () {
      final source = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(key: 'common.ok', value: 'OK'),
          ArbEntry(key: 'loose_key', value: 'no prefix'),
          ArbEntry(key: 'another_bare', value: 'still bare'),
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
      expect(out.arb.entries.map((e) => e.key), ['common.ok']);
      expect(out.bareKeysSkipped, ['loose_key', 'another_bare']);
    });

    test('empty namespaces list does not flag bare keys', () {
      // When filtering is off, bare keys flow through, so we don't warn.
      final source = ArbFile(
        locale: 'en',
        entries: [ArbEntry(key: 'loose_key', value: 'kept')],
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
      expect(out.bareKeysSkipped, isEmpty);
      expect(out.arb.entries.map((e) => e.key), ['loose_key']);
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
