@TestOn('vm')
library;

import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/plural_categories.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

const _sourceItemCount =
    '{count, plural, '
    '=0{No items} =1{1 item} other{{count} items}}';

void main() {
  group('PluralCategoriesRule', () {
    test('flags missing CLDR categories in Arabic', () {
      // Arabic requires zero/one/two/few/many/other. Only "other" present.
      const arSparse =
          '{count, plural, =0{لا توجد عناصر} =1{عنصر واحد} other{{count} عناصر}}';
      final p = project(
        targetLocales: ['ar'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'items', value: _sourceItemCount)],
        ),
        translations: {
          'ar': arb(
            locale: 'ar',
            entries: [ArbEntry(key: 'items', value: arSparse)],
          ),
        },
      );
      final issues = const PluralCategoriesRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.severity, IssueSeverity.error);
      expect(issues.first.locale, 'ar');
      for (final cat in ['zero', 'one', 'two', 'few', 'many']) {
        expect(
          issues.first.message,
          contains(cat),
          reason: 'missing Arabic CLDR category `$cat` should be named',
        );
      }
      expect(issues.first.hint, contains('IN ADDITION TO'));
    });

    test('passes when all required CLDR categories are present', () {
      const arFull =
          '{count, plural, '
          '=0{لا توجد عناصر} =1{عنصر واحد} '
          'zero{لا توجد عناصر} one{عنصر واحد} two{عنصران} '
          'few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}';
      final p = project(
        targetLocales: ['ar'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'items', value: _sourceItemCount)],
        ),
        translations: {
          'ar': arb(
            locale: 'ar',
            entries: [ArbEntry(key: 'items', value: arFull)],
          ),
        },
      );
      expect(const PluralCategoriesRule().run(p), isEmpty);
    });

    test('Japanese needs only `other`', () {
      const ja = '{count, plural, other{{count}件}}';
      final p = project(
        targetLocales: ['ja'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'items', value: _sourceItemCount)],
        ),
        translations: {
          'ja': arb(
            locale: 'ja',
            entries: [ArbEntry(key: 'items', value: ja)],
          ),
        },
      );
      expect(const PluralCategoriesRule().run(p), isEmpty);
    });

    test('warns (not errors) on a locale not in the CLDR table', () {
      const xy = '{count, plural, one{1} other{many}}';
      final p = project(
        targetLocales: ['xy'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'items', value: _sourceItemCount)],
        ),
        translations: {
          'xy': arb(
            locale: 'xy',
            entries: [ArbEntry(key: 'items', value: xy)],
          ),
        },
      );
      final issues = const PluralCategoriesRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.severity, IssueSeverity.warning);
      expect(issues.first.message, contains('not in Dialect'));
    });

    test('does not fire when source isn\'t a plural expression', () {
      final p = project(
        targetLocales: ['ar'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'k', value: 'Plain string')],
        ),
        translations: {
          'ar': arb(
            locale: 'ar',
            entries: [ArbEntry(key: 'k', value: 'نص عادي')],
          ),
        },
      );
      expect(const PluralCategoriesRule().run(p), isEmpty);
    });

    // Real-world bug regression: in the M0+ multi-model validation,
    // Codex 5.3 produced an Arabic translation that kept only =0/=1/other
    // and dropped the CLDR categories — counts 2..10 would render
    // grammatically wrong. The negative fixture below is a minimized
    // version of that output.
    test('regression: Arabic plural with only =0/=1/other fails the check', () {
      const arSparse =
          '{count, plural, '
          '=0{لا توجد عناصر} =1{عنصر واحد} other{{count} عناصر}}';
      final p = project(
        targetLocales: ['ar'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkoutItemCount', value: _sourceItemCount)],
        ),
        translations: {
          'ar': arb(
            locale: 'ar',
            entries: [ArbEntry(key: 'checkoutItemCount', value: arSparse)],
          ),
        },
      );
      final issues = const PluralCategoriesRule().run(p);
      expect(issues, isNotEmpty);
      expect(
        issues.map((i) => i.key).toSet(),
        contains('checkoutItemCount'),
      );
    });

    test('regression: full 6-category Arabic plural passes', () {
      // The positive fixture: all six CLDR categories present alongside
      // the =0/=1 mirrors. Mirror of the Claude post-patch run output.
      const arFull =
          '{count, plural, '
          '=0{لا توجد عناصر} =1{عنصر واحد} '
          'zero{لا توجد عناصر} one{عنصر واحد} two{عنصران} '
          'few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}';
      final p = project(
        targetLocales: ['ar'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkoutItemCount', value: _sourceItemCount)],
        ),
        translations: {
          'ar': arb(
            locale: 'ar',
            entries: [ArbEntry(key: 'checkoutItemCount', value: arFull)],
          ),
        },
      );
      expect(const PluralCategoriesRule().run(p), isEmpty);
    });
  });
}
