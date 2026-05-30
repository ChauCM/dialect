import 'package:dialect/adapters/json_adapter.dart';
import 'package:dialect/arb/arb_file.dart';
import 'package:test/test.dart';

void main() {
  group('JsonAdapter.filenameFor / handles', () {
    test('uses <locale>.json', () {
      expect(JsonAdapter.filenameFor('en'), 'en.json');
      expect(JsonAdapter.filenameFor('pt-BR'), 'pt-BR.json');
    });

    test('handles only the two backend JSON formats', () {
      expect(JsonAdapter.handles('icu-json'), isTrue);
      expect(JsonAdapter.handles('flat-json'), isTrue);
      expect(JsonAdapter.handles('arb'), isFalse);
      expect(JsonAdapter.handles('apple-strings'), isFalse);
    });
  });

  ArbFile arb(List<ArbEntry> entries, {String locale = 'en'}) =>
      ArbFile(locale: locale, entries: entries);

  group('icu-json (verbatim)', () {
    test('flat keys, sorted, 2-space indent, trailing newline, ICU kept', () {
      final file = arb([
        ArbEntry(key: 'commonCancel', value: 'Cancel'),
        ArbEntry(
          key: 'checkoutItemCount',
          value: '{count, plural, =1{1 item} other{{count} items}}',
        ),
      ]);
      final result = JsonAdapter.encode(file, stripPlurals: false);
      expect(
        result.content,
        '{\n'
        '  "checkoutItemCount": "{count, plural, =1{1 item} other{{count} items}}",\n'
        '  "commonCancel": "Cancel"\n'
        '}\n',
      );
      expect(result.collapsedKeys, isEmpty);
    });

    test('emits literal UTF-8, not \\u escapes', () {
      final file = arb([ArbEntry(key: 'commonCancel', value: 'إلغاء')]);
      final result = JsonAdapter.encode(file, stripPlurals: false);
      expect(result.content, contains('إلغاء'));
    });

    test('empty ARB yields a valid empty object', () {
      expect(JsonAdapter.encode(arb([]), stripPlurals: false).content, '{}\n');
    });

    test('idempotent — same bytes on re-encode', () {
      final file = arb([
        ArbEntry(key: 'a', value: 'A'),
        ArbEntry(key: 'b', value: 'B'),
      ]);
      final first = JsonAdapter.encode(file, stripPlurals: false).content;
      final second = JsonAdapter.encode(file, stripPlurals: false).content;
      expect(first, second);
    });
  });

  group('flat-json (plurals stripped)', () {
    test('plural collapses to the other branch', () {
      final file = arb([
        ArbEntry(
          key: 'checkoutItemCount',
          value:
              '{count, plural, =0{No items} =1{1 item} other{{count} items}}',
        ),
      ]);
      final result = JsonAdapter.encode(file, stripPlurals: true);
      expect(result.content, '{\n  "checkoutItemCount": "{count} items"\n}\n');
      expect(result.collapsedKeys, ['checkoutItemCount']);
    });

    test('select collapses to the other branch', () {
      final file = arb([
        ArbEntry(
          key: 'profileGreeting',
          value:
              '{gender, select, female{Welcome back} male{Welcome back} other{Welcome}}',
        ),
      ]);
      final result = JsonAdapter.encode(file, stripPlurals: true);
      expect(result.content, '{\n  "profileGreeting": "Welcome"\n}\n');
      expect(result.collapsedKeys, ['profileGreeting']);
    });

    test('nested ICU inside other is recursively stripped', () {
      final file = arb([
        ArbEntry(
          key: 'socialReplies',
          value:
              '{count, plural, =1{1 reply by {user, select, female{her} male{him} other{them}}} other{{count} replies}}',
        ),
      ]);
      final result = JsonAdapter.encode(file, stripPlurals: true);
      expect(result.content, '{\n  "socialReplies": "{count} replies"\n}\n');
    });

    test('typed placeholder drops its format suffix', () {
      final file = arb([
        ArbEntry(
          key: 'checkoutTotal',
          value: 'Total: {amount, number, currency}',
        ),
      ]);
      final result = JsonAdapter.encode(file, stripPlurals: true);
      expect(result.content, '{\n  "checkoutTotal": "Total: {amount}"\n}\n');
      // No plural/select here — not counted as a lossy collapse.
      expect(result.collapsedKeys, isEmpty);
    });

    test('plain placeholders survive untouched', () {
      final file = arb([
        ArbEntry(key: 'commonWelcome', value: 'Welcome, {userName}'),
      ]);
      final result = JsonAdapter.encode(file, stripPlurals: true);
      expect(
        result.content,
        '{\n  "commonWelcome": "Welcome, {userName}"\n}\n',
      );
      expect(result.collapsedKeys, isEmpty);
    });

    test(
      'missing other branch aborts with a FormatException naming the key',
      () {
        final file = arb([
          ArbEntry(key: 'broken', value: '{count, plural, =1{1 item}}'),
        ]);
        expect(
          () => JsonAdapter.encode(file, stripPlurals: true),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(contains('broken'), contains('other')),
            ),
          ),
        );
      },
    );
  });
}
