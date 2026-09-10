import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/semantic/plural_shape.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

/// A project whose source holds exactly [value] under `k`, with optional
/// placeholder declarations. Every case here is source-side, so no
/// translations are needed.
List<Issue> issuesFor(String value, {Map<String, ArbPlaceholder>? declared}) {
  final p = project(
    targetLocales: const ['vi'],
    source: arb(
      locale: 'en',
      entries: [
        ArbEntry(
          key: 'k',
          value: value,
          metadata: ArbMetadata(namespace: 'app', placeholders: declared),
        ),
      ],
    ),
  );
  return const PluralShapeRule().run(p);
}

void main() {
  group('PluralShapeRule', () {
    test('flags the defect that prompted it: "{count} people"', () {
      final issues = issuesFor('{count} people');
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('"1 people"'));
      expect(issues.first.key, 'k');
      expect(issues.first.severity, IssueSeverity.warning);
    });

    test('names the ack id, so the false positive has an exit', () {
      final issues = issuesFor('{count} people');
      expect(issues.first.hint, contains('--ack plural_shape:source:k'));
      expect(issues.first.hint, contains('plural'));
    });

    test('is silent once the count is wrapped in a plural', () {
      expect(
        issuesFor('{count, plural, one{1 person} other{{count} people}}'),
        isEmpty,
      );
    });

    test('is silent for a selectordinal', () {
      expect(
        issuesFor('{n, selectordinal, one{{n}st} other{{n}th} } place'),
        isEmpty,
      );
    });

    test('a select block does not count as pluralizing the number', () {
      // `select` branches on a category, not a number, so the count is
      // still bare here.
      expect(issuesFor('{g, select, other{{count} photos}}'), hasLength(1));
    });

    test('fires on a declared int placeholder with an unconventional name', () {
      final issues = issuesFor(
        '{howMany} photos',
        declared: {'howMany': ArbPlaceholder(type: 'int')},
      );
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('{howMany}'));
    });

    test('a declared String placeholder is not a count', () {
      expect(
        issuesFor(
          '{total} summary',
          declared: {'total': ArbPlaceholder(type: 'String')},
        ),
        isEmpty,
      );
    });

    test('recognizes the Count suffix convention', () {
      expect(issuesFor('{photoCount} photos'), hasLength(1));
    });

    test('a non-count placeholder is ignored', () {
      expect(issuesFor('{name} photos'), isEmpty);
    });

    group('stays quiet where the number governs nothing', () {
      final quiet = {
        'operand of a preposition': 'Page {n} of {total}',
        'phrase already complete': '{count} remaining',
        'standalone participle': '{count} selected',
        'nothing follows': 'Total: {count}',
        'punctuation follows': '{count}, and counting',
        'no space before the word': '{count}x',
        'another placeholder follows': '{count} {unit}',
      };
      quiet.forEach((name, value) {
        test(name, () => expect(issuesFor(value), isEmpty));
      });
    });

    // Every one of these was a false positive on the first corpus run, and
    // each is singular in form: a verb, an adjective, a unit, a preposition.
    group('stays quiet when the following word is not plural', () {
      final quiet = {
        'a verb': '{count} stepped with you',
        'an adjective': '{liveCount} live now',
        'a unit abbreviation': 'Resend code in {seconds} s',
        'a preposition': '{count} since you last looked',
        'a singular ending in -ss': '{count} progress',
        'a singular ending in -us': '{count} status',
        'a singular ending in -is': '{count} analysis',
      };
      quiet.forEach((name, value) {
        test(name, () => expect(issuesFor(value), isEmpty));
      });
    });

    test('catches irregular plurals, which is the original defect', () {
      expect(issuesFor('{count} people'), hasLength(1));
      expect(issuesFor('{count} children'), hasLength(1));
    });

    test('catches a bare count inside another plural other-branch', () {
      // Real case, verbatim in shape: at count 2, `others` is 1, so the
      // other-branch renders "and 1 others". An existing plural on one
      // variable says nothing about a second one. `others` is not a
      // conventional count name, so this is also the case that the declared
      // `int` type carries on its own.
      final issues = issuesFor(
        '{count, plural, =1{{name} stepped} '
        'other{{name} and {others} others stepped}}',
        declared: {
          'count': ArbPlaceholder(type: 'int'),
          'name': ArbPlaceholder(type: 'String'),
          'others': ArbPlaceholder(type: 'int'),
        },
      );
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('{others}'));
    });

    test('walks past a modifier to reach the noun', () {
      final issues = issuesFor('{count} new messages');
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('"messages"'));
      expect(issues.first.message, isNot(contains('"new"')));
    });

    test('one issue per bare count, not per key', () {
      final issues = issuesFor('{count} photos in {total} albums');
      expect(issues, hasLength(2));
      expect(
        issues.map((i) => i.message).join(),
        allOf(contains('{count}'), contains('{total}')),
      );
    });

    // A third-person singular verb ends in `-s`, so the shape test alone
    // cannot tell it from a plural noun. These shipped as false positives
    // against a `--strict` gate.
    group('a number that labels the word before it counts nothing', () {
      final ints = {
        'goal': ArbPlaceholder(type: 'int'),
        'step': ArbPlaceholder(type: 'int'),
        'level': ArbPlaceholder(type: 'int'),
        'n': ArbPlaceholder(type: 'int'),
        'day': ArbPlaceholder(type: 'int'),
      };
      final quiet = {
        'the reported string': 'Goal {goal} opens now at step {step}.',
        'capitalized label': 'Step {step} unlocks tomorrow',
        'lowercase label': 'Resume at step {step} shows the summary',
        'another verb': 'Level {level} starts here',
        'irregular verb': 'Chapter {n} begins',
        'verb that is also a noun': 'Goal {goal} steps through the list',
      };
      quiet.forEach((name, value) {
        test(name, () => expect(issuesFor(value, declared: ints), isEmpty));
      });

      test('the reported plural string, whose real count is handled', () {
        // Diagnostic case: `count` already carries a correct plural block,
        // and `goal` was flagged inside it. Neither is a defect.
        expect(
          issuesFor(
            '{count, plural, '
            '=1{Goal {goal} opens now at step {step} with one word:} '
            'other{Goal {goal} opens now at step {step} with {count} words:}}',
            declared: {
              ...ints,
              'count': ArbPlaceholder(type: 'int'),
            },
          ),
          isEmpty,
        );
      });
    });

    group('count position keeps the real defect firing', () {
      final loud = {
        'opens the phrase': '{count} steps remaining',
        'after a preposition': 'Synced {count} albums for {total} photos',
        'after a conjunction': '{name} and {others} others stepped',
        'after a determiner': 'Delete the {count} matches',
        'after a verb of having': 'You have {count} steps left',
        'after a degree adverb': 'Only {count} steps left',
      };
      loud.forEach((name, value) {
        test(name, () {
          final declared = {
            'others': ArbPlaceholder(type: 'int'),
            'name': ArbPlaceholder(type: 'String'),
          };
          expect(
            issuesFor(value, declared: declared),
            isNotEmpty,
            reason: value,
          );
        });
      });

      test('an irregular plural does not need the position test', () {
        // "people" is never a verb, so the founding case fires anywhere.
        expect(
          issuesFor(
            'Room {room} people waiting',
            declared: {'room': ArbPlaceholder(type: 'int')},
          ),
          hasLength(1),
        );
      });
    });

    group('a declared role settles it without an ack', () {
      test('identifier is not a count', () {
        expect(
          issuesFor(
            '{goal} steps opened',
            declared: {'goal': ArbPlaceholder(type: 'int', role: 'identifier')},
          ),
          isEmpty,
        );
      });

      test('ordinal is not a count', () {
        expect(
          issuesFor(
            '{try} attempts unlocked',
            declared: {'try': ArbPlaceholder(type: 'int', role: 'ordinal')},
          ),
          isEmpty,
        );
      });

      test('count claims a number the name would hide', () {
        expect(
          issuesFor(
            '{goal} people',
            declared: {'goal': ArbPlaceholder(type: 'String', role: 'count')},
          ),
          hasLength(1),
        );
      });

      test('an unrecognized role falls back rather than silencing', () {
        // `placeholder_role` reports the typo; this rule must not treat it
        // as a waiver.
        expect(
          issuesFor(
            '{count} people',
            declared: {'count': ArbPlaceholder(type: 'int', role: 'identifer')},
          ),
          hasLength(1),
        );
      });
    });

    test('a plural on one count does not excuse a bare second count', () {
      final issues = issuesFor(
        '{count, plural, other{{count} photos}} across {total} albums',
      );
      expect(issues, hasLength(1));
      expect(issues.first.message, contains('{total}'));
    });
  });
}
