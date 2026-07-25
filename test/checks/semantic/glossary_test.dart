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

    group('term-scoped glossary_exempt', () {
      // Two locked terms in one string, each non-literal for its own reason —
      // the Toni Speak case. A blanket exemption would waive both plus every
      // other term; naming them keeps the rest of the glossary enforcing.
      final twoTerms = Glossary(
        terms: [
          GlossaryTerm(
            term: 'take',
            meaning: 'Noun: a stored recording artifact',
            translations: const {'vi': 'bản thu'},
          ),
          GlossaryTerm(
            term: 'sentence',
            meaning: 'Noun: the prompt being read',
            translations: const {'vi': 'câu'},
          ),
          GlossaryTerm(
            term: 'student',
            meaning: 'Noun: the learner',
            translations: const {'vi': 'học viên'},
          ),
        ],
      );

      dynamic p({required ArbMetadata? meta, required String vi}) => project(
        targetLocales: const ['vi'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(
              key: 'setupNoCoachingBody',
              value: 'Let the student read the sentence, one take.',
              metadata: meta,
            ),
          ],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [ArbEntry(key: 'setupNoCoachingBody', value: vi)],
          ),
        },
        glossary: twoTerms,
      );

      test('waives only the named terms', () {
        // Uses neither "bản thu" nor "câu" (deliberate), but does use the
        // canonical "học viên" — so `student` must not fire either.
        final issues = const GlossaryRule().run(
          p(
            meta: ArbMetadata(glossaryExemptTerms: const ['take', 'sentence']),
            vi: 'Hãy để học viên đọc mẫu, một lượt thu.',
          ),
        );
        expect(issues, isEmpty);
      });

      test('still enforces a term that was NOT named', () {
        // Same waivers, but now the translation also drops "học viên".
        final issues = const GlossaryRule().run(
          p(
            meta: ArbMetadata(glossaryExemptTerms: const ['take', 'sentence']),
            vi: 'Hãy để người ấy đọc mẫu, một lượt thu.',
          ),
        );
        expect(issues, hasLength(1));
        expect(issues.single.message, contains('student'));
      });

      test('an unrelated waiver does not silence the real term', () {
        final issues = const GlossaryRule().run(
          p(
            meta: ArbMetadata(glossaryExemptTerms: const ['take']),
            vi: 'Hãy để học viên đọc mẫu, một lượt thu.',
          ),
        );
        expect(issues, hasLength(1));
        expect(issues.single.message, contains('sentence'));
      });

      test('term matching is case-insensitive', () {
        final issues = const GlossaryRule().run(
          p(
            meta: ArbMetadata(
              glossaryExemptTerms: const ['Take', 'SENTENCE', 'Student'],
            ),
            vi: 'Hãy để người ấy đọc mẫu, một lượt thu.',
          ),
        );
        expect(issues, isEmpty);
      });

      test('`true` still waives everything', () {
        final issues = const GlossaryRule().run(
          p(
            meta: ArbMetadata(glossaryExempt: true),
            vi: 'Hãy để người ấy đọc mẫu, một lượt thu.',
          ),
        );
        expect(issues, isEmpty);
      });

      test('no exemption: every unmatched term fires', () {
        final issues = const GlossaryRule().run(
          p(meta: null, vi: 'Hãy để người ấy đọc mẫu, một lượt thu.'),
        );
        expect(issues, hasLength(3));
      });

      test('the hint names the specific term to waive', () {
        final issues = const GlossaryRule().run(
          p(meta: null, vi: 'Hãy để học viên đọc mẫu, một lượt thu.'),
        );
        expect(
          issues.map((i) => i.hint),
          everyElement(contains('"glossary_exempt": [')),
        );
        expect(
          issues.any((i) => i.hint!.contains('["take"]')),
          isTrue,
          reason: 'the hint must be copy-pasteable for the term that fired',
        );
      });
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
