import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/semantic/banned_pattern.dart';
import 'package:dialect/glossary/glossary_loader.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  final noEmDash = Glossary(
    banned: [
      BannedPattern(
        pattern: '—',
        reason: 'Use a comma, a colon, or two sentences.',
      ),
    ],
  );

  /// A project with one key in the source and (optionally) one in `vi`.
  dynamic proj(String english, {String? vi, Glossary? glossary}) => project(
    targetLocales: const ['vi'],
    source: arb(
      locale: 'en',
      entries: [ArbEntry(key: 'k', value: english)],
    ),
    translations: {
      if (vi != null)
        'vi': arb(
          locale: 'vi',
          entries: [ArbEntry(key: 'k', value: vi)],
        ),
    },
    glossary: glossary ?? noEmDash,
  );

  group('BannedPatternRule', () {
    test('no banned block means the rule does not run', () {
      final issues = const BannedPatternRule().run(
        proj('One thing — then another', glossary: Glossary.empty()),
      );
      expect(issues, isEmpty);
    });

    test('catches the pattern in the source locale', () {
      final issues = const BannedPatternRule().run(
        proj('One thing — then another'),
      );
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('`k` in `en`'));
      expect(issues.first.severity, IssueSeverity.warning);
      // A source-side issue carries no target locale, which is what makes
      // its ack id read `banned_pattern:source:k`.
      expect(issues.first.locale, isNull);
      expect(issues.first.hint, contains('--ack banned_pattern:source:k'));
    });

    test('the reason is the hint, so it says what to write instead', () {
      final issues = const BannedPatternRule().run(proj('A — B'));
      expect(
        issues.first.hint,
        contains('Use a comma, a colon, or two sentences.'),
      );
    });

    test('catches the pattern in a translation', () {
      final issues = const BannedPatternRule().run(
        proj('Clean english', vi: 'Một thứ — rồi thứ khác'),
      );
      expect(issues, hasLength(1));
      expect(issues.first.locale, 'vi');
      expect(issues.first.hint, contains('--ack banned_pattern:vi:k'));
    });

    test('reports both sides when both offend', () {
      final issues = const BannedPatternRule().run(proj('A — B', vi: 'C — D'));
      expect(issues, hasLength(2));
      expect(issues.map((i) => i.locale), containsAll([null, 'vi']));
    });

    test('clean copy produces nothing', () {
      final issues = const BannedPatternRule().run(
        proj('A clean line', vi: 'Một dòng sạch'),
      );
      expect(issues, isEmpty);
    });

    test('locales narrows a rule to the language it is about', () {
      final englishOnly = Glossary(
        banned: [
          BannedPattern(
            pattern: 'utilize',
            reason: "Prefer 'use'.",
            locales: const ['en'],
          ),
        ],
      );
      final issues = const BannedPatternRule().run(
        proj('Utilize this', vi: 'utilize này', glossary: englishOnly),
      );
      expect(issues, hasLength(1));
      expect(issues.first.locale, isNull, reason: 'en only');
    });

    test('a literal pattern is matched literally, not as a regex', () {
      final dots = Glossary(
        banned: [BannedPattern(pattern: 'a.b', reason: 'No.')],
      );
      // `a.b` as a regex would match "axb"; as a literal it must not.
      expect(
        const BannedPatternRule().run(proj('axb', glossary: dots)),
        isEmpty,
      );
      expect(
        const BannedPatternRule().run(proj('a.b', glossary: dots)),
        hasLength(1),
      );
    });

    test('regex: true opts into pattern matching and quotes what it hit', () {
      final verbs = Glossary(
        banned: [
          BannedPattern(
            pattern: r'\b(utilize|leverage)\b',
            reason: 'Plain verbs.',
            isRegex: true,
          ),
        ],
      );
      final issues = const BannedPatternRule().run(
        proj('We leverage this', glossary: verbs),
      );
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('"leverage"'));
    });

    group('except: standing exemptions', () {
      Glossary withExcept(List<String> except) => Glossary(
        banned: [
          BannedPattern(pattern: '—', reason: 'Use a comma.', except: except),
        ],
      );

      test('an excepted key is not reported', () {
        final issues = const BannedPatternRule().run(
          proj('A — B', glossary: withExcept(['k'])),
        );
        expect(issues, isEmpty);
      });

      test('the exemption survives an edit, unlike an ack', () {
        // Same key, different copy, em-dash still there: a ruling is not
        // fingerprinted, so it still holds.
        final issues = const BannedPatternRule().run(
          proj(
            'Totally rewritten — but still ruled',
            glossary: withExcept(['k']),
          ),
        );
        expect(issues, isEmpty);
      });

      test('a key that no longer carries the pattern is reported as dead', () {
        final issues = const BannedPatternRule().run(
          proj('Clean copy now', glossary: withExcept(['k'])),
        );
        expect(issues, hasLength(1));
        expect(issues.first.message, contains('no longer contain it'));
        expect(issues.first.message, contains('k'));
        expect(issues.first.hint, contains('Remove those names'));
      });

      test('a key that does not exist at all is reported as dead', () {
        final issues = const BannedPatternRule().run(
          proj('A — B', glossary: withExcept(['k', 'goneKey'])),
        );
        expect(issues, hasLength(1));
        expect(issues.first.message, contains('goneKey'));
        // `k` is still earning its place, so it is not named.
        expect(issues.first.message, isNot(contains(', k')));
      });

      test('one issue per pattern, however long the dead list', () {
        final issues = const BannedPatternRule().run(
          proj('Clean', glossary: withExcept(['a', 'b', 'c'])),
        );
        expect(issues, hasLength(1));
        expect(issues.first.message, startsWith('3 key(s)'));
      });

      test('an exemption earned in any locale counts as live', () {
        // The English was cleaned up but the Vietnamese still carries it, so
        // the name on the list is still doing work.
        final issues = const BannedPatternRule().run(
          proj('Clean now', vi: 'Vẫn — còn', glossary: withExcept(['k'])),
        );
        expect(issues, isEmpty);
      });
    });

    test('matching ignores case', () {
      final verbs = Glossary(
        banned: [BannedPattern(pattern: 'utilize', reason: 'Plain verbs.')],
      );
      expect(
        const BannedPatternRule().run(proj('Utilize it', glossary: verbs)),
        hasLength(1),
      );
    });
  });

  group('glossary.yaml banned: parsing', () {
    test('parses a full entry', () {
      final g = Glossary.parse('''
banned:
  - pattern: "—"
    reason: "Use a comma."
  - pattern: '\\bvery\\b'
    regex: true
    reason: "Cut it."
    locales: [en]
''');
      expect(g.banned, hasLength(2));
      expect(g.banned.first.pattern, '—');
      expect(g.banned.first.isRegex, isFalse);
      expect(g.banned.first.locales, isEmpty);
      expect(g.banned.last.isRegex, isTrue);
      expect(g.banned.last.locales, ['en']);
    });

    test('parses except:', () {
      final g = Glossary.parse(
        'banned:\n'
        '  - pattern: "—"\n'
        '    reason: "Use a comma."\n'
        '    except: [pushBodyOne, pushBodyTwo]\n',
      );
      expect(g.banned.single.except, ['pushBodyOne', 'pushBodyTwo']);
    });

    test('except: must be a list', () {
      expect(
        () => Glossary.parse(
          'banned:\n  - pattern: "x"\n    reason: "y"\n    except: nope\n',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('except'),
          ),
        ),
      );
    });

    test('banned: stands alone without a terms: block', () {
      final g = Glossary.parse('banned:\n  - pattern: "x"\n    reason: "y"\n');
      expect(g.terms, isEmpty);
      expect(g.banned, hasLength(1));
    });

    test('terms: still parses when banned: is absent', () {
      final g = Glossary.parse('''
terms:
  - term: "Book"
    meaning: "Verb"
    translations: {es: "Reservar"}
''');
      expect(g.terms, hasLength(1));
      expect(g.banned, isEmpty);
    });

    test('a missing reason is rejected, since the reason is the hint', () {
      expect(
        () => Glossary.parse('banned:\n  - pattern: "x"\n'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('reason'),
          ),
        ),
      );
    });

    test('an uncompilable regex is rejected at load time', () {
      expect(
        () => Glossary.parse(
          'banned:\n  - pattern: "a(b"\n    regex: true\n    reason: "no"\n',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('does not compile'),
          ),
        ),
      );
    });

    test('banned: must be a list', () {
      expect(
        () => Glossary.parse('banned: nope\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
