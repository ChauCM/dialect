import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/arb/freshness.dart';
import 'package:dialect/arb/source_hash.dart';
import 'package:test/test.dart';

void main() {
  final bookNowHash = computeSourceHash('Book Now');

  group('isStaleEntry', () {
    final hashes = {'a': bookNowHash};

    test('mismatched stored hash → stale', () {
      final e = ArbEntry(
        key: 'a',
        value: 'Reservar',
        metadata: ArbMetadata(sourceHash: 'oldhash000000000'),
      );
      expect(isStaleEntry(e, hashes), isTrue);
    });

    test('matching stored hash → fresh', () {
      final e = ArbEntry(
        key: 'a',
        value: 'Reservar',
        metadata: ArbMetadata(sourceHash: bookNowHash),
      );
      expect(isStaleEntry(e, hashes), isFalse);
    });

    test('no stored hash → untracked, not stale', () {
      expect(
        isStaleEntry(ArbEntry(key: 'a', value: 'Reservar'), hashes),
        false,
      );
    });

    test('key absent from source → not stale', () {
      final e = ArbEntry(
        key: 'ghost',
        value: 'x',
        metadata: ArbMetadata(sourceHash: 'whatever00000000'),
      );
      expect(isStaleEntry(e, hashes), isFalse);
    });
  });

  group('normalizeTranslation', () {
    final source = ArbFile(
      locale: 'en',
      entries: [ArbEntry(key: 'a', value: 'Book Now')],
    );
    final hashes = computeSourceHashes(source);

    test('stamps source_hash onto an unlocked entry missing one', () {
      final arb = ArbFile(
        locale: 'es',
        entries: [ArbEntry(key: 'a', value: 'Reservar')],
      );
      final out = normalizeTranslation(arb, hashes);
      expect(out.entries.single.metadata?.sourceHash, bookNowHash);
      expect(out.entries.single.metadata?.locked, isFalse);
    });

    test('never overwrites an existing (stale) hash — staleness survives', () {
      final arb = ArbFile(
        locale: 'es',
        entries: [
          ArbEntry(
            key: 'a',
            value: 'Reservar',
            metadata: ArbMetadata(sourceHash: 'oldhash000000000'),
          ),
        ],
      );
      final out = normalizeTranslation(arb, hashes);
      expect(
        out.entries.single.metadata?.sourceHash,
        'oldhash000000000',
        reason: 'a stale entry stays stale until it is re-translated',
      );
    });

    test('preserves locked + its hash, never auto-stamps a locked entry', () {
      final arb = ArbFile(
        locale: 'es',
        entries: [
          ArbEntry(
            key: 'a',
            value: 'Reservar',
            metadata: ArbMetadata(locked: true),
          ),
        ],
      );
      final out = normalizeTranslation(arb, hashes);
      expect(out.entries.single.metadata?.locked, isTrue);
      expect(
        out.entries.single.metadata?.sourceHash,
        isNull,
        reason: 'locked entries are managed by the lock flow, not stamped',
      );
    });

    test('strips descriptive metadata but keeps state', () {
      final arb = ArbFile(
        locale: 'es',
        entries: [
          ArbEntry(
            key: 'a',
            value: 'Reservar',
            metadata: ArbMetadata(
              namespace: 'checkout',
              description: 'leaked from source',
              sourceHash: bookNowHash,
            ),
          ),
        ],
      );
      final meta = normalizeTranslation(arb, hashes).entries.single.metadata;
      expect(meta?.namespace, isNull);
      expect(meta?.description, isNull);
      expect(meta?.sourceHash, bookNowHash);
    });

    test('empty value is not stamped', () {
      final arb = ArbFile(
        locale: 'es',
        entries: [ArbEntry(key: 'a', value: '')],
      );
      expect(normalizeTranslation(arb, hashes).entries.single.metadata, isNull);
    });
  });
}
