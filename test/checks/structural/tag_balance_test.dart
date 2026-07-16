import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/tag_balance.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('TagBalanceRule', () {
    test('passes when the translation moves the tags but keeps the set', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'hint',
              value: 'Commenting counts as <b>stepping with {name}</b>',
            ),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              // Word order moved; the tag moved with the meaning.
              ArbEntry(
                key: 'hint',
                value: '<b>Bước cùng {name}</b> ngay khi bạn bình luận',
              ),
            ],
          ),
        },
      );
      expect(const TagBalanceRule().run(p), isEmpty);
    });

    test('passes on tag-free values', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'plain', value: 'A plain 1 < 2 sentence')],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [ArbEntry(key: 'plain', value: 'Một câu thường 1 < 2')],
          ),
        },
      );
      expect(const TagBalanceRule().run(p), isEmpty);
    });

    test('flags a dropped closing tag as unbalanced', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'k', value: 'You stepped with <j>{title}</j>.'),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(key: 'k', value: 'Bạn đã bước cùng <j>{title}.'),
            ],
          ),
        },
      );
      final issues = const TagBalanceRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.severity, IssueSeverity.error);
      expect(issues.first.message, contains('unbalanced'));
      expect(issues.first.hint, contains('<j>'));
    });

    test('flags a translation whose tag set differs from the source', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'k', value: 'Lives at <b>stepo.app/@{u}</b>'),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              // Balanced, but the wrong tag: renders literally in the UI.
              ArbEntry(key: 'k', value: 'Nằm tại <j>stepo.app/@{u}</j>'),
            ],
          ),
        },
      );
      final issues = const TagBalanceRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('<j>'));
      expect(issues.first.message, contains('<b>'));
    });

    test('flags a dropped tag pair (set mismatch, still balanced)', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'k', value: '<b>{n}</b> of <b>{m}</b> done'),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(key: 'k', value: 'Xong <b>{n}</b> trong {m}'),
            ],
          ),
        },
      );
      final issues = const TagBalanceRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('1x <b>'));
      expect(issues.first.message, contains('2x <b>'));
    });

    test(
      'passes when a single-category locale collapses a tagged plural',
      () {
        // Vietnamese has one CLDR category (other), so a source plural whose
        // every branch carries <b> collapses to a single `other` branch that
        // carries <b> once. Both RENDER exactly one <b> run. The raw counts
        // differ (source 2x, vi 1x) but must not be compared.
        final p = project(
          targetLocales: ['vi'],
          source: arb(
            locale: 'en',
            entries: [
              ArbEntry(
                key: 'k',
                value:
                    '{count, plural, =1{<b>1</b> step} other{<b>{count}</b> steps}}',
              ),
            ],
          ),
          translations: {
            'vi': arb(
              locale: 'vi',
              entries: [
                ArbEntry(
                  key: 'k',
                  value: '{count, plural, other{<b>{count}</b> bước}}',
                ),
              ],
            ),
          },
        );
        expect(const TagBalanceRule().run(p), isEmpty);
      },
    );

    test('passes when two collapsed plurals each keep their tag', () {
      // Two plural placeholders joined by a separator; each branch carries one
      // <b>. A single rendering shows two <b> runs on both sides.
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'k',
              value:
                  '{a, plural, =1{<b>1</b> badge} other{<b>{a}</b> badges}} · '
                  '{b, plural, =1{<b>1</b> given} other{<b>{b}</b> given}}',
            ),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(
                key: 'k',
                value:
                    '{a, plural, other{<b>{a}</b> huy hiệu}} · '
                    '{b, plural, other{<b>{b}</b> đã trao}}',
              ),
            ],
          ),
        },
      );
      expect(const TagBalanceRule().run(p), isEmpty);
    });

    test('still flags a plural translation that drops a tag from its branch', () {
      // Collapsing does not hide a genuine loss: the vi `other` branch carries
      // no <b> at all, so the rendered counts differ (source 1x, vi 0x).
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'k',
              value:
                  '{count, plural, =1{<b>1</b> step} other{<b>{count}</b> steps}}',
            ),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(key: 'k', value: '{count, plural, other{{count} bước}}'),
            ],
          ),
        },
      );
      final issues = const TagBalanceRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('no tags'));
      expect(issues.first.message, contains('1x <b>'));
    });

    test('flags an unbalanced SOURCE value on the source file', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'k', value: 'A <b>broken run')],
        ),
      );
      final issues = const TagBalanceRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.locale, 'en');
      expect(issues.first.message, contains('Source'));
    });

    test('crossed nesting is unbalanced, not clever', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'k', value: '<b>bold <j>both</b> serif</j>'),
          ],
        ),
      );
      final issues = const TagBalanceRule().run(p);
      expect(issues, hasLength(1));
    });
  });
}
