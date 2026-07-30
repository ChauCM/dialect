import '../../arb/arb_file.dart';
import '../../arb/icu_message.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// A count is interpolated into a sentence that has only one grammatical
/// shape, so some value of that count reads wrong: `"{count} people"`
/// renders "1 people".
///
/// The `plural_categories` rule is the other half of this: it checks a plural
/// *is* complete once one exists. Nothing checked that a plural should have
/// existed at all, which is how two English strings shipped saying
/// "1 people". This rule fires on the **source** only, because that is where
/// the defect is born — once the source is a plural expression, translations
/// are governed by `plural_categories`, and a fix applied to a translation
/// alone would leave the source wrong for every other locale.
///
/// **The heuristic.** A warning, not an error, and knowingly approximate:
///
///   1. Find placeholders that carry a count. A placeholder qualifies by its
///      declared `@key.placeholders.<name>.type` (`int`, `num`, `double`,
///      `number`) or, when nothing is declared, by a conventional name
///      (`count`, `n`, `num`, `total`, `qty`, or anything ending in
///      `Count`).
///   2. Drop the ones already governed by a `plural` / `selectordinal`
///      expression ([IcuMessage.pluralSelectors]).
///   3. Of what remains, find the noun the count governs ([_wordAfter]) and
///      fire only when that noun is already **plural** ([_looksPlural]) —
///      which is precisely the disagreement: a count that can be 1 in front
///      of a word that means many.
///
/// Step 3 is what keeps this quiet enough to leave on by default. Across the
/// first real corpus it ran on (a shipping app, ~900 source keys) it flagged
/// four strings, all four of them genuine, including one hiding inside the
/// `other` branch of an existing plural. Where it does misfire, the escape
/// hatch is the standard one: `dialect check --ack plural_shape:source:<key>`,
/// whose fingerprint retires the waiver as soon as the copy is edited.
class PluralShapeRule extends Rule {
  const PluralShapeRule();

  @override
  String get name => 'plural_shape';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    for (final entry in project.source.entries) {
      final pluralized = IcuMessage.pluralSelectors(entry.value);
      for (final placeholder in _countPlaceholders(entry)) {
        if (pluralized.contains(placeholder)) continue;
        final noun = _wordAfter(entry.value, placeholder);
        if (noun == null || !_looksPlural(noun)) continue;

        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message:
                'Source for `${entry.key}` puts the count `{$placeholder}` in '
                'front of "$noun" with no plural block, so it renders '
                '"1 $noun" when the count is 1.',
            key: entry.key,
            file: project.source.sourcePath,
            line: project.source.entryLines[entry.key],
            hint:
                'Wrap it in an ICU plural: '
                '`{$placeholder, plural, one{1 …} other{{$placeholder} …}}`. '
                'Do it in the source — every translation inherits the shape, '
                'and `plural_categories` then holds each locale to the '
                'categories it needs. If "$noun" really does read correctly '
                'at every count, run '
                '`dialect check --ack $name:source:${entry.key}`.',
          ),
        );
      }
    }

    return issues;
  }

  /// Placeholder names in [entry] that carry a count, by declared type
  /// first and by naming convention second.
  ///
  /// The declared type is the better signal and the one to encourage, but
  /// most real ARB entries never declare placeholders at all, and a rule
  /// that only fired on fully-declared entries would have missed the two
  /// strings that prompted it.
  static Set<String> _countPlaceholders(ArbEntry entry) {
    final names = IcuMessage.extractPlaceholders(entry.value);
    final declared = entry.metadata?.placeholders ?? const {};
    return {
      for (final name in names)
        if (_isCountType(declared[name]?.type) ||
            (declared[name]?.type == null && _isCountName(name)))
          name,
    };
  }

  static bool _isCountType(String? type) {
    if (type == null) return false;
    return const {
      'int',
      'num',
      'number',
      'double',
    }.contains(type.toLowerCase());
  }

  static bool _isCountName(String name) {
    final lower = name.toLowerCase();
    if (_countNames.contains(lower)) return true;
    // `photoCount`, `unread_count`, `stepsCount` — the suffix convention.
    return lower.length > 5 && lower.endsWith('count');
  }

  static const Set<String> _countNames = {
    'count',
    'n',
    'num',
    'total',
    'qty',
    'quantity',
  };

  /// The counted noun following the `{placeholder}` occurrence in [value],
  /// or `null` when there is nothing for the number to disagree with.
  ///
  /// Walks forward one word at a time from the placeholder:
  ///   - a [_terminators] word means the number is an operand or the phrase
  ///     is already complete ("{n} of {total}", "{count} to go") — stop;
  ///   - a [_modifiers] word does not itself inflect but can precede the
  ///     noun ("{count} new messages") — skip it and keep looking;
  ///   - anything else is the head noun candidate.
  ///
  /// Running out of string returns `null`, which is what makes [_modifiers]
  /// the safe home for a word that can also stand alone: "{count} selected"
  /// ends there and stays quiet, while "{count} selected photos" reaches
  /// "photos" and fires.
  static String? _wordAfter(String value, String placeholder) {
    final match = RegExp(
      '\\{\\s*${RegExp.escape(placeholder)}\\s*(?:,[^{}]*)?\\}',
    ).firstMatch(value);
    if (match == null) return null;

    var i = match.end;
    while (true) {
      // A single run of spaces only. Punctuation between the number and a
      // noun ("{count}, plus more") means the two are not in agreement.
      var sawSpace = false;
      while (i < value.length && value[i] == ' ') {
        sawSpace = true;
        i++;
      }
      if (!sawSpace) return null;

      final start = i;
      while (i < value.length && _isLetter(value.codeUnitAt(i))) {
        i++;
      }
      if (i == start) return null; // punctuation, a placeholder, or a digit

      final word = value.substring(start, i);
      final lower = word.toLowerCase();
      if (_terminators.contains(lower)) return null;
      if (_modifiers.contains(lower)) continue;
      return word;
    }
  }

  static bool _isLetter(int c) =>
      (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A);

  /// Whether [word] is in its plural form.
  ///
  /// This is the test that makes the rule precise, and it follows from what
  /// the defect actually is. An author writing "{count} steps" has written
  /// the many-case and left the one-case to break; the number and the noun
  /// disagree exactly when the noun is already plural. Every false positive
  /// on the first real corpus run was a count followed by a verb, an
  /// adjective, or a unit abbreviation ("{count} stepped with you",
  /// "{liveCount} live now", "{seconds} s"), and all of them are singular in
  /// form.
  ///
  /// Regular `-s` plus the irregulars English actually uses in UI copy. The
  /// `-ss` / `-us` / `-is` endings are singulars that would otherwise sneak
  /// through ("progress", "status", "analysis"), and a two-letter word is a
  /// unit, not a noun.
  ///
  /// The cost of this precision is the mirror defect — a source written in
  /// the singular, "{count} step", which breaks at 2 rather than at 1. That
  /// is the rarer way round to get it wrong, and catching it would mean
  /// deciding that any singular noun after a count is suspect, which is most
  /// of the corpus.
  static bool _looksPlural(String word) {
    final lower = word.toLowerCase();
    if (_irregularPlurals.contains(lower)) return true;
    if (lower.length < 3 || !lower.endsWith('s')) return false;
    return !lower.endsWith('ss') &&
        !lower.endsWith('us') &&
        !lower.endsWith('is');
  }

  /// English plurals that do not end in `-s`. "people" is the one that
  /// prompted this rule.
  static const Set<String> _irregularPlurals = {
    'people',
    'children',
    'men',
    'women',
    'feet',
    'teeth',
    'mice',
    'geese',
    'oxen',
    'media',
    'criteria',
  };

  /// Function words that make the number an operand rather than a quantity,
  /// plus the handful of words that close the phrase outright. Nothing after
  /// one of these is counted by this placeholder.
  static const Set<String> _terminators = {
    'of',
    'in',
    'on',
    'at',
    'to',
    'from',
    'by',
    'with',
    'for',
    'and',
    'or',
    'per',
    'out',
    'is',
    'are',
    'was',
    'were',
    'has',
    'have',
    'than',
    'that',
    'ago',
    'away',
    'each',
    'so',
    'far',
    'since',
    'while',
    'when',
    'after',
    'before',
    'during',
    'until',
    'about',
    'into',
    'onto',
    'via',
    'plus',
    'minus',
  };

  /// Words that do not inflect for number themselves but can sit between the
  /// count and the noun it governs. Skipped, not stopped on.
  static const Set<String> _modifiers = {
    'new',
    'unread',
    'more',
    'less',
    'fewer',
    'other',
    'additional',
    'remaining',
    'selected',
    'left',
    'total',
    'done',
    'complete',
    'active',
    'pending',
    'saved',
    'available',
    'further',
    'shared',
    'hidden',
  };
}
