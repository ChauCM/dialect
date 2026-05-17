@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/plural_categories.dart';
import 'package:test/test.dart';

import '../../_support/repo_root.dart';
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

    // Real-world fixture: gpt-5-3's actual Arabic itemCount (negative)
    // vs. claude-post-patch's actual Arabic itemCount (positive), both
    // from the M0+ multi-model validation.
    test('real-world bug fixture: Codex 5.3 ar.arb fails', () {
      final negative = ArbParser.parse(
        File(
          repoPath([
            'example',
            '_validation',
            'runs',
            'gpt-5-3',
            'dialect',
            'translations',
            'ar.arb',
          ]),
        ).readAsStringSync(),
      );
      final source = ArbParser.parse(
        File(
          repoPath([
            'example',
            '_validation',
            'runs',
            'gpt-5-3',
            'dialect',
            'source',
            'en.arb',
          ]),
        ).readAsStringSync(),
      );
      final p = project(
        targetLocales: ['ar'],
        source: source,
        translations: {'ar': negative},
      );
      final issues = const PluralCategoriesRule().run(p);
      expect(
        issues,
        isNotEmpty,
        reason: 'Codex Arabic plural keeps only =0/=1/other → fail',
      );
      // The flagged keys are the ones with a plural source value.
      final flaggedKeys = issues.map((i) => i.key).toSet();
      expect(flaggedKeys, contains('checkout.itemCount'));
    });

    test('real-world fixture: Claude post-patch ar.arb passes', () {
      final positive = ArbParser.parse(
        File(
          repoPath([
            'example',
            '_validation',
            'runs',
            'claude-post-patch',
            'dialect',
            'translations',
            'ar.arb',
          ]),
        ).readAsStringSync(),
      );
      final source = ArbParser.parse(
        File(
          repoPath([
            'example',
            '_validation',
            'runs',
            'claude-post-patch',
            'dialect',
            'source',
            'en.arb',
          ]),
        ).readAsStringSync(),
      );
      final p = project(
        targetLocales: ['ar'],
        source: source,
        translations: {'ar': positive},
      );
      expect(const PluralCategoriesRule().run(p), isEmpty);
    });
  });
}
