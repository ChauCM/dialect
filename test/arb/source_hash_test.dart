import 'package:dialect/arb/source_hash.dart';
import 'package:test/test.dart';

void main() {
  group('computeSourceHash', () {
    test('outputs lowercase 16-char hex', () {
      final h = computeSourceHash('Book Now');
      expect(h.length, 16);
      expect(
        RegExp(r'^[0-9a-f]{16}$').hasMatch(h),
        isTrue,
        reason: 'must be lowercase hex with no prefix',
      );
    });

    test('is deterministic — same value → same hash', () {
      final a = computeSourceHash('checkout flow copy');
      final b = computeSourceHash('checkout flow copy');
      expect(a, b);
    });

    test('different values produce different hashes', () {
      expect(
        computeSourceHash('Book Now'),
        isNot(computeSourceHash('Book this stay')),
      );
    });

    test('matches the spec\'s worked example for "Book Now"', () {
      // SHA-256("Book Now") first 16 lowercase hex = the value
      // dialect/spec/source_hash.md commits to. Locking this lets us
      // change the implementation without silently changing the
      // on-disk fingerprint format.
      expect(computeSourceHash('Book Now'), '67be79359de4aa3f');
    });

    test('hashes the empty string deterministically', () {
      expect(computeSourceHash(''), 'e3b0c44298fc1c14');
    });

    test('non-ASCII characters are UTF-8 encoded before hashing', () {
      // Same Vietnamese phrase (NFC) — non-empty hash, deterministic.
      final a = computeSourceHash('Chuyến đi của bạn');
      final b = computeSourceHash('Chuyến đi của bạn');
      expect(a, b);
      expect(a.length, 16);
    });
  });
}
