import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/check_runner.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/semantic/width_budget.dart';
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
      expect(info!.sourceChars, 12);
      expect(info.maxChars, 17); // max(round(12*1.4)=17, 12+4=16)
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
