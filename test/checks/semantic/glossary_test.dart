import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/semantic/glossary.dart';
import 'package:dialect/glossary/glossary_loader.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  final bookGlossary = Glossary(
    terms: [
      GlossaryTerm(
        term: 'Book',
        meaning: 'Verb: make a reservation',
        translations: const {'es': 'Reservar', 'ja': '予約する', 'de': 'Buchen'},
      ),
    ],
  );

  group('GlossaryRule', () {
    test('warns when translation does not use the canonical term', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkout.cta', value: 'Book Now')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              // Spanish translation drops the canonical "Reservar" stem.
              ArbEntry(key: 'checkout.cta', value: 'Comprar ahora'),
            ],
          ),
        },
        glossary: bookGlossary,
      );
      final issues = const GlossaryRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('Reservar'));
      expect(issues.first.hint, contains('glossary_exempt'));
    });

    test('accepts inflected forms of the canonical', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkout.cta', value: 'Book Now')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            // "Reserva" is the noun form — same stem, glossary should pass.
            entries: [ArbEntry(key: 'checkout.cta', value: 'Reserva ahora')],
          ),
        },
        glossary: bookGlossary,
      );
      expect(const GlossaryRule().run(p), isEmpty);
    });

    test('accepts the canonical CJK form', () {
      final p = project(
        targetLocales: const ['ja'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkout.cta', value: 'Book Now')],
        ),
        translations: {
          'ja': arb(
            locale: 'ja',
            entries: [ArbEntry(key: 'checkout.cta', value: '今すぐ予約する')],
          ),
        },
        glossary: bookGlossary,
      );
      expect(const GlossaryRule().run(p), isEmpty);
    });

    test('honors @key.glossary_exempt on the source entry', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'community.bookClub',
              value: 'Join the Book Club',
              metadata: ArbMetadata(glossaryExempt: true),
            ),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(
                key: 'community.bookClub',
                // Deliberately doesn't use "Reservar" because it's literally
                // a physical-book club.
                value: 'Únete al Club de Libros',
              ),
            ],
          ),
        },
        glossary: bookGlossary,
      );
      expect(const GlossaryRule().run(p), isEmpty);
    });

    test('only matches whole-word source occurrences', () {
      // "Bookmark" contains "book" but only as part of a longer word.
      // Whole-word match must skip.
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'settings.bookmark', value: 'Add Bookmark')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(key: 'settings.bookmark', value: 'Añadir marcador'),
            ],
          ),
        },
        glossary: bookGlossary,
      );
      expect(const GlossaryRule().run(p), isEmpty);
    });

    test('no-ops when the glossary is empty', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkout.cta', value: 'Book Now')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'checkout.cta', value: 'Comprar ahora')],
          ),
        },
        // glossary omitted → Glossary.empty()
      );
      expect(const GlossaryRule().run(p), isEmpty);
    });

    test('skips locales the glossary does not list', () {
      // 'ar' is not in the glossary above; rule shouldn't warn even if
      // the translation looks suspicious.
      final p = project(
        targetLocales: const ['ar'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'checkout.cta', value: 'Book Now')],
        ),
        translations: {
          'ar': arb(
            locale: 'ar',
            entries: [ArbEntry(key: 'checkout.cta', value: 'اشتر الآن')],
          ),
        },
        glossary: bookGlossary,
      );
      expect(const GlossaryRule().run(p), isEmpty);
    });

    test('does not fire when the term appears only as a placeholder name', () {
      // Feedback #6: `{journey}` is the placeholder name, not the English
      // word — the value passes it through untranslated, so the glossary
      // must not demand a translation for it.
      final journeyGlossary = Glossary(
        terms: [
          GlossaryTerm(
            term: 'journey',
            meaning: 'A tracked goal',
            translations: const {'vi': 'hành trình'},
          ),
        ],
      );
      final p = project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'stepDetailCrumb', value: 'Step · {journey}'),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            // Placeholder passed through; no "hành trình" needed.
            entries: [
              ArbEntry(key: 'stepDetailCrumb', value: 'Bước · {journey}'),
            ],
          ),
        },
        glossary: journeyGlossary,
      );
      expect(
        const GlossaryRule().run(p),
        isEmpty,
        reason: 'a placeholder-only term is not literal copy',
      );
    });

    test(
      'still fires when the term is literal copy inside a plural branch',
      () {
        final journeyGlossary = Glossary(
          terms: [
            GlossaryTerm(
              term: 'journey',
              meaning: 'A tracked goal',
              translations: const {'vi': 'hành trình'},
            ),
          ],
        );
        final p = project(
          targetLocales: const ['vi'],
          source: arb(
            locale: 'en',
            entries: [
              ArbEntry(
                key: 'journeyCount',
                value: '{n, plural, one{1 journey} other{{n} journeys}}',
              ),
            ],
          ),
          translations: {
            'vi': arb(
              locale: 'vi',
              // Vietnamese drops the canonical stem entirely.
              entries: [ArbEntry(key: 'journeyCount', value: '{n} mục')],
            ),
          },
          glossary: journeyGlossary,
        );
        final issues = const GlossaryRule().run(p);
        expect(issues, hasLength(1));
        expect(issues.first.message, contains('hành trình'));
      },
    );
  });
}
