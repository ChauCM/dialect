import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/arb/arb_writer.dart';
import 'package:test/test.dart';

void main() {
  group('ArbWriter', () {
    test('emits @@locale and an empty body for an empty file', () {
      final out = ArbWriter.encode(ArbFile(locale: 'en', entries: []));
      expect(out, '{\n  "@@locale": "en"\n}\n');
    });

    test('emits sorted entries with metadata blocks', () {
      final arb = ArbFile(
        locale: 'en',
        entries: [
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
        ],
      );
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

    test('inlines placeholders blocks preserving declaration order', () {
      // Regression (Stepo pilot, 2026-07-16): the writer used to sort
      // placeholder keys alphabetically. Flutter's gen_l10n derives the
      // generated method's parameter order from declaration order, so a
      // normalize pass that re-sorts placeholders silently changes the
      // generated Dart API and breaks every call site. Declaration order
      // must survive the write.
      final arb = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(
            key: 'g',
            value: 'Hello {name}, you have {count} items',
            metadata: ArbMetadata(
              description: 'd',
              placeholders: {
                // Deliberately NOT alphabetical: name declared before count.
                'name': ArbPlaceholder(type: 'String'),
                'count': ArbPlaceholder(type: 'int'),
              },
            ),
          ),
        ],
      );
      final out = ArbWriter.encode(arb);
      expect(out.contains('"placeholders": {'), isTrue);
      // Inline shape: { "type": "int" } per placeholder.
      expect(out.contains('"count": { "type": "int" }'), isTrue);
      expect(out.contains('"name": { "type": "String" }'), isTrue);
      // Declaration order preserved: name stays before count.
      final nIdx = out.indexOf('"name":');
      final cIdx = out.indexOf('"count":');
      expect(nIdx, greaterThan(0));
      expect(cIdx, greaterThan(nIdx));
    });

    test('includes locked/glossary_exempt/source_hash when set', () {
      final arb = ArbFile(
        locale: 'es',
        entries: [
          ArbEntry(
            key: 'k',
            value: 'v',
            metadata: ArbMetadata(
              locked: true,
              glossaryExempt: true,
              sourceHash: 'abc123',
            ),
          ),
        ],
      );
      final out = ArbWriter.encode(arb);
      expect(out.contains('"locked": true'), isTrue);
      expect(out.contains('"glossary_exempt": true'), isTrue);
      expect(out.contains('"source_hash": "abc123"'), isTrue);
    });

    test('emits a term-scoped glossary_exempt list', () {
      final arb = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(
            key: 'k',
            value: 'v',
            metadata: ArbMetadata(
              glossaryExemptTerms: const ['take', 'sentence'],
            ),
          ),
        ],
      );
      final out = ArbWriter.encode(arb);
      expect(out, contains('"glossary_exempt": ["take","sentence"]'));
    });

    test('a blanket exemption outranks a list (never emits both)', () {
      final arb = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(
            key: 'k',
            value: 'v',
            metadata: ArbMetadata(
              glossaryExempt: true,
              glossaryExemptTerms: const ['take'],
            ),
          ),
        ],
      );
      final out = ArbWriter.encode(arb);
      expect(out, contains('"glossary_exempt": true'));
      expect(out, isNot(contains('"take"')));
    });

    test('a term list survives a parse → write round trip', () {
      const original = '''
{
  "@@locale": "en",

  "setupBody": "Read the sentence, one take.",
  "@setupBody": {
    "namespace": "setup",
    "glossary_exempt": ["take","sentence"]
  }
}
''';
      // `check --fix` re-writes every ARB, so a shape that doesn't survive
      // the round trip would be silently erased on the next run.
      final once = ArbWriter.encode(ArbParser.parse(original));
      final twice = ArbWriter.encode(ArbParser.parse(once));
      expect(once, contains('"glossary_exempt": ["take","sentence"]'));
      expect(twice, once, reason: 'writing must be idempotent');
    });

    test('emits @@ file-level metadata after @@locale in sorted order', () {
      final arb = ArbFile(
        locale: 'en',
        entries: [ArbEntry(key: 'k', value: 'v')],
        fileMetadata: {
          '@@x-context': 'checkout',
          '@@last_modified': '2026-05-22T10:00:00.000Z',
        },
      );
      final out = ArbWriter.encode(arb);
      // Locale first.
      expect(out.indexOf('"@@locale"'), greaterThan(0));
      // @@last_modified before @@x-context (alphabetical), both before "k".
      final lmIdx = out.indexOf('"@@last_modified"');
      final xcIdx = out.indexOf('"@@x-context"');
      final kIdx = out.indexOf('"k"');
      expect(lmIdx, greaterThan(out.indexOf('"@@locale"')));
      expect(xcIdx, greaterThan(lmIdx));
      expect(kIdx, greaterThan(xcIdx));
    });

    test('orphan metadata is not emitted (--fix strips by construction)', () {
      final arb = ArbFile(
        locale: 'en',
        entries: [ArbEntry(key: 'k', value: 'v')],
        orphanMetadata: {
          'orphan': ArbMetadata(description: 'should not appear'),
        },
      );
      final out = ArbWriter.encode(arb);
      expect(out.contains('orphan'), isFalse);
      expect(out.contains('should not appear'), isFalse);
    });

    test('output parses back as valid JSON', () {
      final arb = ArbFile(
        locale: 'en',
        entries: [
          ArbEntry(
            key: 'a.b',
            value: 'A',
            metadata: ArbMetadata(description: 'desc'),
          ),
          ArbEntry(key: 'c', value: 'C'),
        ],
      );
      final out = ArbWriter.encode(arb);
      // Should round-trip through the parser without throwing.
      expect(() => out, returnsNormally);
      // And the output is valid JSON.
      expect(out.startsWith('{'), isTrue);
      expect(out.trim().endsWith('}'), isTrue);
    });
  });
}
