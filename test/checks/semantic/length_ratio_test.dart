import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/semantic/length_ratio.dart';
import 'package:dialect/project/dialect_project.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('LengthRatioRule', () {
    test('does not warn when ratio sits inside the default band', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'checkout.ctaBookNow', value: 'Book this stay now'),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(
                key: 'checkout.ctaBookNow',
                value: 'Reservar esta estancia ahora',
              ),
            ],
          ),
        },
      );
      expect(const LengthRatioRule().run(p), isEmpty);
    });

    test('warns when ratio is below the minimum', () {
      final p = project(
        targetLocales: const ['ja'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'checkout.confirmationMessageLong',
              value: 'Your booking has been confirmed successfully',
            ),
          ],
        ),
        translations: {
          'ja': arb(
            locale: 'ja',
            entries: [
              ArbEntry(key: 'checkout.confirmationMessageLong', value: '完了'),
            ],
          ),
        },
      );
      final issues = const LengthRatioRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('shorter'));
    });

    test('source shorter than minSourceLength gates the upper bound too', () {
      // Source is 7 chars (< minSourceLength 8). Even with a wildly
      // longer translation, no warning fires — short strings are too
      // noisy to police.
      final p = project(
        targetLocales: const ['de'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkout.confirmButton', value: 'Confirm')],
        ),
        translations: {
          'de': arb(
            locale: 'de',
            entries: [
              ArbEntry(
                key: 'checkout.confirmButton',
                value:
                    'Bitte bestätigen Sie Ihre Buchung jetzt sofort und ohne Verzögerung',
              ),
            ],
          ),
        },
      );
      expect(const LengthRatioRule().run(p), isEmpty);
    });

    test('triggers upper bound when source is long enough', () {
      final p = project(
        targetLocales: const ['de'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'checkout.confirmButton', value: 'Confirm booking'),
          ],
        ),
        translations: {
          'de': arb(
            locale: 'de',
            entries: [
              ArbEntry(
                key: 'checkout.confirmButton',
                value:
                    'Bitte bestätigen Sie Ihre Buchung jetzt sofort und ohne Verzögerung',
              ),
            ],
          ),
        },
      );
      final issues = const LengthRatioRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('longer'));
    });

    test('skips very short source strings', () {
      final p = project(
        targetLocales: const ['ja'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'common.ok', value: 'OK')],
        ),
        translations: {
          'ja': arb(
            locale: 'ja',
            entries: [ArbEntry(key: 'common.ok', value: 'はい')],
          ),
        },
      );
      expect(const LengthRatioRule().run(p), isEmpty);
    });

    test('honors per-locale overrides from dialect.yaml extras', () {
      // German legitimately runs longer; widen the band to skip a
      // warning we would otherwise raise.
      final p = project(
        targetLocales: const ['de'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'checkout.bookNow', value: 'Confirm booking'),
          ],
        ),
        translations: {
          'de': arb(
            locale: 'de',
            entries: [
              ArbEntry(
                key: 'checkout.bookNow',
                value: 'Bitte bestätigen Sie Ihre Buchung',
              ),
            ],
          ),
        },
        extras: const {
          'length_ratio': {
            'de': [0.5, 3.5],
          },
        },
      );
      expect(const LengthRatioRule().run(p), isEmpty);
    });

    test('reports the actual ratio in the message', () {
      final p = project(
        targetLocales: const ['ja'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'checkout.confirmation',
              value: 'Your booking is confirmed.',
            ),
          ],
        ),
        translations: {
          'ja': arb(
            locale: 'ja',
            entries: [ArbEntry(key: 'checkout.confirmation', value: '完')],
          ),
        },
      );
      final issue = const LengthRatioRule().run(p).single;
      expect(issue.message, contains('×'));
    });

    group('display columns', () {
      DialectProject one(String locale, String source, String value) => project(
        targetLocales: [locale],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'k', value: source)],
        ),
        translations: {
          locale: arb(
            locale: locale,
            entries: [ArbEntry(key: 'k', value: value)],
          ),
        },
      );

      const source = 'Please enter your password'; // 26 columns

      test('a Korean translation fine by columns is not "too short"', () {
        // 7 characters would be 0.27x (below 0.3); it is 13 columns, 0.5x.
        expect(
          const LengthRatioRule().run(one('ko', source, '비밀번호 입력')),
          isEmpty,
        );
      });

      test('a Korean translation that is short in columns still trips', () {
        final issue = const LengthRatioRule()
            .run(one('ko', source, '확인'))
            .single;
        expect(issue.message, contains('0.15×'));
        expect(issue.message, contains('shorter'));
      });

      test('Latin is measured exactly as before', () {
        final issue = const LengthRatioRule()
            .run(one('es', source, 'Clave'))
            .single;
        expect(issue.message, contains('0.19×'));
        expect(
          const LengthRatioRule().run(
            one('es', source, 'Introduce tu contraseña'),
          ),
          isEmpty,
        );
      });

      test('Vietnamese, precomposed or decomposed, is unchanged', () {
        // Each combining mark was one UTF-16 unit and is one column.
        const pre = 'Ch\u1ec9nh s\u1eeda'; // 9
        const dec = 'Chi\u0309nh su\u031B\u0309a'; // 12
        final a = const LengthRatioRule().run(
          one('vi', 'Edit your profile now', pre),
        );
        final b = const LengthRatioRule().run(
          one('vi', 'Edit your profile now', dec),
        );
        expect(a, isEmpty); // 9 / 21 = 0.43
        expect(b, isEmpty); // 12 / 21 = 0.57
      });

      test('a source is skipped below 8 columns, not 8 characters', () {
        // 3 Latin columns: skipped. 4 hanzi = 8 columns: checked.
        expect(
          const LengthRatioRule().run(one('ko', 'Cat', '고양이 고양이 고양이')),
          isEmpty,
        );
        final p = project(
          sourceLocale: 'zh',
          targetLocales: const ['ko'],
          source: arb(
            locale: 'zh',
            entries: [ArbEntry(key: 'k', value: '密码设置')],
          ),
          translations: {
            'ko': arb(
              locale: 'ko',
              entries: [ArbEntry(key: 'k', value: '비밀번호 설정 화면에서 바꾸세요 지금 바로')],
            ),
          },
        );
        expect(const LengthRatioRule().run(p), hasLength(1));
      });
    });
  });
}
