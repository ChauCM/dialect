import 'package:dialect/arb/arb_parser.dart';
import 'package:test/test.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

void main() {
  group('ArbParser', () {
    test('parses a minimal ARB', () {
      final arb = ArbParser.parse('''
{
  "@@locale": "en",
  "greeting": "Hello"
}
''');
      expect(arb.locale, 'en');
      expect(arb.entries.length, 1);
      expect(arb.entries.first.key, 'greeting');
      expect(arb.entries.first.value, 'Hello');
      expect(arb.entries.first.metadata, isNull);
    });

    test('parses metadata block alongside key/value', () {
      final arb = ArbParser.parse('''
{
  "@@locale": "en",
  "checkout.bookNow": "Book Now",
  "@checkout.bookNow": {
    "description": "Primary CTA on checkout.",
    "context": "checkout_screen"
  }
}
''');
      final entry = arb.entryFor('checkout.bookNow');
      expect(entry, isNotNull);
      expect(entry!.metadata, isNotNull);
      expect(entry.metadata!.description, 'Primary CTA on checkout.');
      expect(entry.metadata!.context, 'checkout_screen');
    });

    test('parses placeholders block', () {
      final arb = ArbParser.parse('''
{
  "@@locale": "en",
  "greet": "Hello {name}",
  "@greet": {
    "description": "greeting",
    "placeholders": { "name": { "type": "String" } }
  }
}
''');
      final ph = arb.entryFor('greet')!.metadata!.placeholders!;
      expect(ph.keys, containsAll(<String>['name']));
      expect(ph['name']!.type, 'String');
    });

    test('parses locked + glossary_exempt flags', () {
      final arb = ArbParser.parse('''
{
  "@@locale": "es",
  "checkout.bookNow": "Reservar",
  "@checkout.bookNow": { "locked": true, "glossary_exempt": true }
}
''');
      final meta = arb.entryFor('checkout.bookNow')!.metadata!;
      expect(meta.locked, isTrue);
      expect(meta.glossaryExempt, isTrue);
    });

    test('preserves unknown metadata fields in extras', () {
      final arb = ArbParser.parse('''
{
  "@@locale": "en",
  "k": "v",
  "@k": { "x_custom": "preserved", "description": "d" }
}
''');
      final meta = arb.entryFor('k')!.metadata!;
      expect(meta.description, 'd');
      expect(meta.extras['x_custom'], 'preserved');
    });

    test('NFC-normalizes Vietnamese string values on read', () {
      // Generate an NFD version of a Vietnamese phrase. NFD splits
      // precomposed accented letters into base + combining marks.
      const nfc = 'Chuyến đi của bạn'; // Vietnamese: "Your trip"
      final nfd = unorm.nfd(nfc);

      // Sanity-check the test setup: NFD has more code units than NFC.
      expect(
        nfd.length,
        greaterThan(nfc.length),
        reason: 'NFD must have combining marks split out',
      );
      expect(
        nfd,
        isNot(equals(nfc)),
        reason: 'NFC and NFD should differ for these chars',
      );

      final arb = ArbParser.parse('''
{
  "@@locale": "vi",
  "home.title": ${_jsonStringLiteral(nfd)}
}
''');

      final value = arb.entryFor('home.title')!.value;
      expect(
        value,
        nfc,
        reason:
            'parser must normalize NFD→NFC so two visually-equal '
            'strings hash identically',
      );
    });

    test('throws on missing @@locale', () {
      expect(
        () => ArbParser.parse('{"k": "v"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on non-object root', () {
      expect(
        () => ArbParser.parse('"not an object"'),
        throwsA(isA<FormatException>()),
      );
    });

    test('preserves orphan @key blocks for the structural check', () {
      // An `@key` block without a corresponding key/value pair is a
      // structural error `dialect check` (M4) needs to flag. The parser
      // surfaces it in `orphanMetadata` so M4 doesn't have to re-read raw
      // JSON. `dialect check --fix` strips orphans by construction.
      final arb = ArbParser.parse('''
{
  "@@locale": "en",
  "@orphan": { "description": "no value" }
}
''');
      expect(
        arb.entryFor('orphan'),
        isNull,
        reason: 'orphan does not become a real entry',
      );
      expect(arb.orphanMetadata.keys, ['orphan']);
      expect(arb.orphanMetadata['orphan']!.description, 'no value');
    });

    test('preserves unknown @@ file-level metadata', () {
      // Flutter gen_l10n emits @@last_modified by default. Other tools
      // emit @@x-context or custom @@-prefixed fields. Silently dropping
      // them on read would corrupt user data when `dialect sync` writes
      // back.
      final arb = ArbParser.parse('''
{
  "@@locale": "en",
  "@@last_modified": "2026-05-22T10:00:00.000Z",
  "@@x-context": "checkout",
  "k": "v"
}
''');
      expect(arb.fileMetadata['@@last_modified'], '2026-05-22T10:00:00.000Z');
      expect(arb.fileMetadata['@@x-context'], 'checkout');
      expect(
        arb.fileMetadata.containsKey('@@locale'),
        isFalse,
        reason: '@@locale lives on its own field, not in fileMetadata',
      );
    });
  });
}

String _jsonStringLiteral(String s) {
  // Minimal JSON-string escape sufficient for the chars in our Vietnamese
  // test fixture (no quotes, no backslashes, no controls).
  return '"$s"';
}
