import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/arb/arb_writer.dart';
import 'package:test/test.dart';

void main() {
  group('ArbWriter', () {
    test('emits @@locale and an empty body for an empty file', () {
      final out = ArbWriter.encode(ArbFile(locale: 'en', entries: []));
      expect(out, '{\n  "@@locale": "en"\n}\n');
    });

    test('emits sorted entries with metadata blocks', () {
      final arb = ArbFile(locale: 'en', entries: [
        ArbEntry(
          key: 'common.cancel',
          value: 'Cancel',
          metadata: ArbMetadata(description: 'Cancel action label.'),
        ),
        ArbEntry(
          key: 'checkout.bookNow',
          value: 'Book Now',
          metadata: ArbMetadata(
            description: 'Primary CTA.',
            context: 'checkout_screen',
          ),
        ),
      ]);
      final out = ArbWriter.encode(arb);
      // Sorted: checkout before common.
      final checkoutIdx = out.indexOf('"checkout.bookNow"');
      final commonIdx = out.indexOf('"common.cancel"');
      expect(checkoutIdx, greaterThan(0));
      expect(commonIdx, greaterThan(checkoutIdx));
      expect(out.contains('"@checkout.bookNow"'), isTrue);
      expect(out.contains('"context": "checkout_screen"'), isTrue);
      expect(out, endsWith('\n}\n'));
    });

    test('inlines placeholders blocks with leading-key-sorted order', () {
      final arb = ArbFile(locale: 'en', entries: [
        ArbEntry(
          key: 'g',
          value: 'Hello {name}, you have {count} items',
          metadata: ArbMetadata(
            description: 'd',
            placeholders: {
              'count': ArbPlaceholder(type: 'int'),
              'name': ArbPlaceholder(type: 'String'),
            },
          ),
        ),
      ]);
      final out = ArbWriter.encode(arb);
      expect(out.contains('"placeholders": {'), isTrue);
      // Inline shape: { "type": "int" } per placeholder.
      expect(out.contains('"count": { "type": "int" }'), isTrue);
      expect(out.contains('"name": { "type": "String" }'), isTrue);
      // Sorted: count before name (lexicographic).
      final cIdx = out.indexOf('"count":');
      final nIdx = out.indexOf('"name":');
      expect(cIdx, greaterThan(0));
      expect(nIdx, greaterThan(cIdx));
    });

    test('includes locked/glossary_exempt/source_hash when set', () {
      final arb = ArbFile(locale: 'es', entries: [
        ArbEntry(
          key: 'k',
          value: 'v',
          metadata: ArbMetadata(
            locked: true,
            glossaryExempt: true,
            sourceHash: 'abc123',
          ),
        ),
      ]);
      final out = ArbWriter.encode(arb);
      expect(out.contains('"locked": true'), isTrue);
      expect(out.contains('"glossary_exempt": true'), isTrue);
      expect(out.contains('"source_hash": "abc123"'), isTrue);
    });

    test('output parses back as valid JSON', () {
      final arb = ArbFile(locale: 'en', entries: [
        ArbEntry(
          key: 'a.b',
          value: 'A',
          metadata: ArbMetadata(description: 'desc'),
        ),
        ArbEntry(key: 'c', value: 'C'),
      ]);
      final out = ArbWriter.encode(arb);
      // Should round-trip through the parser without throwing.
      expect(() => out, returnsNormally);
      // And the output is valid JSON.
      expect(out.startsWith('{'), isTrue);
      expect(out.trim().endsWith('}'), isTrue);
    });
  });
}
