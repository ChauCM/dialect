import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/check_runner.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/semantic/width_budget.dart';
import 'package:dialect/project/dialect_project.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

/// A source entry carrying width-budget metadata in its `@key` block.
ArbEntry src(
  String key,
  String value, {
  Map<String, Object?> extras = const {},
}) {
  return ArbEntry(
    key: key,
    value: value,
    metadata: ArbMetadata(extras: extras),
  );
}

void main() {
  group('WidthBudgetRule', () {
    test('a key with no budget is never checked (opt-in)', () {
      // A wildly-expanded translation, but the source declares no budget —
      // body copy must never be policed.
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'onboarding.blurb', value: 'Edit profile')],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(
                key: 'onboarding.blurb',
                value: 'Chỉnh sửa trang cá nhân của bạn ngay bây giờ nhé',
              ),
            ],
          ),
        },
      );
      expect(const WidthBudgetRule().run(p), isEmpty);
    });

    test('absolute x-max-length flags an over-cap translation', () {
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src('profile.edit', 'Edit', extras: {'x-max-length': 8}),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              // 9 chars > 8.
              ArbEntry(key: 'profile.edit', value: 'Chinh sua'),
            ],
          ),
        },
      );
      final issues = const WidthBudgetRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.single.ruleName, 'width_budget');
      expect(issues.single.severity, IssueSeverity.warning);
      expect(issues.single.message, contains('over'));
    });

    test('under an absolute cap: no warning', () {
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src('profile.edit', 'Edit', extras: {'x-max-length': 12}),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [ArbEntry(key: 'profile.edit', value: 'Chinh sua')],
          ),
        },
      );
      expect(const WidthBudgetRule().run(p), isEmpty);
    });

    test('slot max_ratio: the real "Edit profile" overflow case', () {
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src(
              'profile.editProfile',
              'Edit profile',
              extras: {'x-slot': 'button'},
            ),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              // The literal full translation — far over 1.4× of 12.
              ArbEntry(
                key: 'profile.editProfile',
                value: 'Chỉnh sửa trang cá nhân',
              ),
            ],
          ),
        },
        extras: const {
          'slots': {
            'button': {'max_ratio': 1.4},
          },
        },
      );
      final issues = const WidthBudgetRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('button'));
    });

    test('slot max_ratio: the concise form passes', () {
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src(
              'profile.editProfile',
              'Edit profile',
              extras: {'x-slot': 'button'},
            ),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              // "Chỉnh sửa" ≈ 9 ≤ 17 (max(round(12*1.4), 12+4)).
              ArbEntry(key: 'profile.editProfile', value: 'Chỉnh sửa'),
            ],
          ),
        },
        extras: const {
          'slots': {
            'button': {'max_ratio': 1.4},
          },
        },
      );
      expect(const WidthBudgetRule().run(p), isEmpty);
    });

    test('ratio grace floor spares the shortest labels', () {
      // Source "Go" (2). ratio 1.4 → 3, but the grace floor is 2+4=6, so the
      // budget is 6. "Tiep" (4) exceeds the raw ratio but the floor saves it.
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src('common.go', 'Go', extras: {'x-slot': 'button'}),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [ArbEntry(key: 'common.go', value: 'Tiep')],
          ),
        },
        extras: const {
          'slots': {
            'button': {'max_ratio': 1.4},
          },
        },
      );
      expect(const WidthBudgetRule().run(p), isEmpty);
    });

    test('absolute budget flags an over-tight source itself', () {
      // English "Edit profile" (12) already busts a hard 10-char slot —
      // reported source-side (no locale) so it surfaces before translation.
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src(
              'profile.editProfile',
              'Edit profile',
              extras: {'x-max-length': 10},
            ),
          ],
        ),
      );
      final issues = const WidthBudgetRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.single.locale, isNull);
      expect(issues.single.message, contains('Source'));
    });

    test('an x-slot naming an undeclared slot is ignored, not an error', () {
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src('x', 'Edit profile', extras: {'x-slot': 'nonexistent'}),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(key: 'x', value: 'Chỉnh sửa trang cá nhân của bạn'),
            ],
          ),
        },
        extras: const {
          'slots': {
            'button': {'max_ratio': 1.4},
          },
        },
      );
      expect(const WidthBudgetRule().run(p), isEmpty);
    });

    test('placeholder names do not inflate the measured length', () {
      // Literal copy is "  left" (6); the {count} identifier is excluded.
      // Budget 8 → fits, even though the raw string is 14 chars.
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src('cart.left', '{count} left', extras: {'x-max-length': 8}),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [ArbEntry(key: 'cart.left', value: 'Còn {count}')],
          ),
        },
      );
      expect(const WidthBudgetRule().run(p), isEmpty);
    });
  });

  group('width_budget strict gating', () {
    ArbFile overflowSource() => arb(
      locale: 'en',
      entries: [
        src('profile.edit', 'Edit', extras: {'x-max-length': 4}),
      ],
    );
    Map<String, ArbFile> overflowTranslation() => {
      'vi': arb(
        locale: 'vi',
        entries: [ArbEntry(key: 'profile.edit', value: 'Chinh sua')],
      ),
    };

    test('is a warning; plain --strict does NOT promote it', () {
      final p = project(
        targetLocales: const ['vi'],
        source: overflowSource(),
        translations: overflowTranslation(),
      );
      final result = runChecks(p, rules: const [WidthBudgetRule()]);
      expect(result.issues, hasLength(1));
      expect(
        result.failing(strict: true, strictLength: false).toList(),
        isEmpty,
        reason: 'width_budget must not be promoted by --strict alone',
      );
    });

    test('--strict-length promotes it to a failure', () {
      final p = project(
        targetLocales: const ['vi'],
        source: overflowSource(),
        translations: overflowTranslation(),
      );
      final result = runChecks(p, rules: const [WidthBudgetRule()]);
      expect(
        result.failing(strict: true, strictLength: true).toList(),
        hasLength(1),
      );
    });

    test('width_budget is in the strict-length-gated set', () {
      expect(strictLengthGatedRules, contains('width_budget'));
    });
  });

  group('width is counted in display columns', () {
    // East Asian Wide and Fullwidth code points are two columns; everything
    // else is one. Combining marks keep their old treatment: a code point
    // each (no zero-width handling).
    DialectProject one({
      required String locale,
      required String source,
      required String value,
      required Map<String, Object?> extras,
      Map<String, Object?> config = const {},
      String sourceLocale = 'en',
    }) => project(
      sourceLocale: sourceLocale,
      targetLocales: [locale],
      source: arb(
        locale: sourceLocale,
        entries: [src('k', source, extras: extras)],
      ),
      translations: {
        locale: arb(
          locale: locale,
          entries: [ArbEntry(key: 'k', value: value)],
        ),
      },
      extras: config,
    );

    test('a Hangul string over a cap that passed by code-point count', () {
      // 6 code points, 11 columns (익숙한 = 6, space = 1, 단어 = 4).
      final p = one(
        locale: 'ko',
        source: 'Known',
        value: '익숙한 단어',
        extras: {'x-max-length': 8},
      );
      final issues = const WidthBudgetRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('11 columns'));
      expect(issues.single.message, contains('budget of 8'));
    });

    test('mixed Latin and Hangul: exact column count', () {
      final p = one(
        locale: 'ko',
        source: 'Level 외움', // "Level " = 6, 외움 = 4
        value: 'x',
        extras: {'x-slot': 'button'},
        config: const {
          'slots': {
            'button': {'max_ratio': 1.4},
          },
        },
      );
      final info = widthBudgetFor(p.source.entries.single, p)!;
      expect(info.sourceColumns, 10);
      expect(info.maxColumns, 14); // max(round(10*1.4)=14, 10+4=14)
    });

    test('ratio slot: hanzi on both sides is measured the same way', () {
      // Source 学习 中文 = 4 + 1 + 4 = 9 columns. grace 0, ratio 1.2 -> 11.
      DialectProject p(String value) => one(
        locale: 'ja',
        sourceLocale: 'zh',
        source: '学习 中文',
        value: value,
        extras: {'x-slot': 'tab'},
        config: const {
          'slots': {
            'tab': {'max_ratio': 1.2, 'grace': 0},
          },
        },
      );
      // 6 code points but 12 columns: over 11. Code points would give
      // 6 vs a budget of 6 and pass.
      final over = const WidthBudgetRule().run(p('学习日本语中'));
      expect(over, hasLength(1));
      expect(over.single.message, contains('12 columns'));
      expect(over.single.message, contains('budget of 11'));
      expect(over.single.message, contains('source is 9'));
      // 9 columns: fits.
      expect(const WidthBudgetRule().run(p('学习 日本')), isEmpty);
    });

    test('Latin and Vietnamese are measured as before', () {
      WidthBudgetInfo info(String source) {
        final p = one(
          locale: 'vi',
          source: source,
          value: 'x',
          extras: {'x-max-length': 20},
        );
        return widthBudgetFor(p.source.entries.single, p)!;
      }

      expect(info('Edit profile').sourceColumns, 12);
      // Precomposed: one code point per letter.
      expect(info('Ch\u1ec9nh s\u1eeda').sourceColumns, 9);
      // Decomposed: each combining mark still counts one, as it always did.
      expect(info('Chi\u0309nh su\u031B\u0309a').sourceColumns, 12);
    });
  });

  group('widthBudgetFor helper', () {
    test('resolves the effective budget for the translate plan', () {
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            src(
              'profile.editProfile',
              'Edit profile',
              extras: {'x-slot': 'button'},
            ),
          ],
        ),
        extras: const {
          'slots': {
            'button': {'max_ratio': 1.4},
          },
        },
      );
      final info = widthBudgetFor(p.source.entries.single, p);
      expect(info, isNotNull);
      expect(info!.sourceColumns, 12);
      expect(info.maxColumns, 17); // max(round(12*1.4)=17, 12+4=16)
      expect(info.label, contains('button'));
    });

    test('returns null when no budget is declared', () {
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'plain', value: 'Edit profile')],
        ),
      );
      expect(widthBudgetFor(p.source.entries.single, p), isNull);
    });
  });
}
