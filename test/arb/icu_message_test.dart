import 'package:dialect/arb/icu_message.dart';
import 'package:test/test.dart';

void main() {
  group('IcuMessage.extractPlaceholders', () {
    test('finds a simple placeholder', () {
      expect(IcuMessage.extractPlaceholders('Hello {name}'), {'name'});
    });

    test('finds multiple placeholders in one string', () {
      expect(IcuMessage.extractPlaceholders('Hi {first} and {second}'), {
        'first',
        'second',
      });
    });

    test('returns empty set for plain strings', () {
      expect(IcuMessage.extractPlaceholders('No placeholders here'), isEmpty);
    });

    test('finds the variable name in a typed placeholder', () {
      expect(IcuMessage.extractPlaceholders('{count, number, compactLong}'), {
        'count',
      });
    });

    test('finds the plural variable name', () {
      expect(
        IcuMessage.extractPlaceholders(
          '{count, plural, =0{no items} other{{count} items}}',
        ),
        {'count'},
      );
    });

    test('finds nested placeholders inside plural branches', () {
      expect(
        IcuMessage.extractPlaceholders(
          '{count, plural, other{Hi {name}, {count} items}}',
        ),
        {'count', 'name'},
      );
    });

    test('treats escaped braces as literals', () {
      // '{' / '}' in a quoted run is NOT a placeholder.
      expect(
        IcuMessage.extractPlaceholders("Bring '{your}' notebook"),
        isEmpty,
      );
    });

    test("two single-quotes are a literal apostrophe", () {
      // No placeholder; ''  is just `'` and there is no `{name}`.
      expect(IcuMessage.extractPlaceholders("It''s fine"), isEmpty);
    });
  });

  group('IcuMessage.extractPluralCategories', () {
    test('returns null for non-plural messages', () {
      expect(IcuMessage.extractPluralCategories('Hello {name}'), isNull);
      expect(IcuMessage.extractPluralCategories('plain string'), isNull);
    });

    test('returns categories in source order', () {
      expect(
        IcuMessage.extractPluralCategories(
          '{n, plural, =0{none} =1{one} other{{n} items}}',
        ),
        ['=0', '=1', 'other'],
      );
    });

    test('handles Arabic 6-category plural', () {
      expect(
        IcuMessage.extractPluralCategories(
          '{count, plural, '
          'zero{0} one{1} two{2} few{few} many{many} other{other}}',
        ),
        ['zero', 'one', 'two', 'few', 'many', 'other'],
      );
    });

    test('detects =N and CLDR categories mixed (the convention pattern)', () {
      // The Round-2 convention requires mirroring =0/=1 AND keeping CLDR
      // categories. The extractor returns all of them in source order.
      expect(
        IcuMessage.extractPluralCategories(
          '{count, plural, '
          '=0{none} =1{one} zero{none-cldr} one{one-cldr} other{other}}',
        ),
        ['=0', '=1', 'zero', 'one', 'other'],
      );
    });

    test('detects selectordinal as ordinal plural', () {
      expect(
        IcuMessage.extractPluralCategories(
          '{n, selectordinal, one{1st} two{2nd} few{3rd} other{{n}th}}',
        ),
        ['one', 'two', 'few', 'other'],
      );
    });

    test('returns null for select (not plural)', () {
      expect(
        IcuMessage.extractPluralCategories(
          '{gender, select, male{he} female{she} other{they}}',
        ),
        isNull,
      );
    });
  });

  group('IcuMessage.hasExpressions', () {
    test('true for placeholders', () {
      expect(IcuMessage.hasExpressions('Hello {name}'), isTrue);
    });

    test('true for plurals', () {
      expect(IcuMessage.hasExpressions('{n, plural, other{x}}'), isTrue);
    });

    test('false for plain strings', () {
      expect(IcuMessage.hasExpressions('Plain text.'), isFalse);
    });

    test('false when all braces are escaped', () {
      expect(IcuMessage.hasExpressions("Use '{' and '}' literally"), isFalse);
    });
  });
}
