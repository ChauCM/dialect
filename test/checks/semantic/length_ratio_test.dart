import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/semantic/length_ratio.dart';
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
  });
}
