import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/checks/structural/orphan_metadata.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('OrphanMetadataRule', () {
    test('flags orphan @key in source', () {
      // Parse with an actual @-only block to exercise the parser path.
      final source = ArbParser.parse('''
{
  "@@locale": "en",
  "real": "value",
  "@orphan": { "description": "no matching key" }
}
''');
      final p = project(targetLocales: const [], source: source);
      final issues = const OrphanMetadataRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.key, 'orphan');
      expect(issues.first.locale, isNull);
      expect(issues.first.hint, contains('--fix'));
    });

    test('flags orphan @key in a translation', () {
      final source = ArbParser.parse('''
{ "@@locale": "en", "k": "v" }
''');
      final es = ArbParser.parse('''
{
  "@@locale": "es",
  "k": "v-es",
  "@stranded": { "description": "shouldn't be here" }
}
''');
      final p = project(
        targetLocales: ['es'],
        source: source,
        translations: {'es': es},
      );
      final issues = const OrphanMetadataRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.locale, 'es');
      expect(issues.first.key, 'stranded');
    });

    test('passes when no orphan blocks exist', () {
      final source = ArbParser.parse('''
{
  "@@locale": "en",
  "k": "v",
  "@k": { "description": "with matching key" }
}
''');
      final p = project(targetLocales: const [], source: source);
      expect(const OrphanMetadataRule().run(p), isEmpty);
    });
  });
}
