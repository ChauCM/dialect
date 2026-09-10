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
///   4. For a regular `-s` candidate, require the placeholder to be in
///      **count position** ([_inCountPosition]) — see below.
///
/// **Why step 4 exists.** An English third-person singular verb ends in `-s`,
/// so [_looksPlural] cannot tell "opens" from "people" by shape alone, and
/// `"Goal {goal} opens now"` read as `"1 opens"`. The rule shipped asserting
/// that its misfires were "a verb, an adjective, or a unit … all singular in
/// form"; that was true of the calibration corpus, which happened to contain
/// no `Label {n} verb-s` string, and false of English. The disambiguator has
/// to be the text *before* the placeholder, because "steps" is a plural noun
/// in "{count} steps" and a verb in "Goal {goal} steps" — the word itself
/// carries no answer.
///
/// English counts forward: a number that counts either opens its phrase or
/// follows a function word ("and {n} others", "in {n} albums"), while a
/// number that follows a bare noun labels that noun ("Goal 3", "step 7") and
/// the `-s` word after it is the sentence's verb. Irregular plurals skip the
/// gate: "people" and "children" are never verbs, and that is the case the
/// rule was written for.
///
/// Erring quiet here is deliberate. A missed warning costs a re-read; a false
/// one blocks a `--strict` push over correct copy.
///
/// **Saying it outright.** `type: int` covers both "how many" and "which
/// one". An author can settle it declaratively with
/// `"role": "identifier"` (or `"ordinal"`) on the placeholder, which is a
/// fact about the variable rather than a waiver on one wording — it survives
/// a rewrite, where an ack does not. Where the rule still misfires on
/// undeclared copy, the escape hatch is the standard one:
/// `dialect check --ack plural_shape:source:<key>`, whose fingerprint retires
/// the waiver as soon as the copy is edited.
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
        if (noun == null) continue;
        if (!_isCountedNoun(noun, entry.value, placeholder)) continue;

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
        if (_carriesCount(declared[name], name)) name,
    };
  }

  /// Whether the placeholder named [name] holds a quantity this rule should
  /// reason about.
  ///
  /// A declared `role` is the author speaking directly and outranks both the
  /// type and the name: `identifier` and `ordinal` are numbers the sentence
  /// does not count, and `count` claims one that a name like `goal` would
  /// otherwise hide. An unrecognized role is ignored here and reported by
  /// `placeholder_role`, so a typo cannot quietly disable the check.
  static bool _carriesCount(ArbPlaceholder? declared, String name) {
    switch (declared?.role) {
      case 'count':
        return true;
      case 'identifier':
      case 'ordinal':
        return false;
    }
    return _isCountType(declared?.type) ||
        (declared?.type == null && _isCountName(name));
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

  /// Whether [noun] is a plural noun this [placeholder] is counting, rather
  /// than the verb of a sentence that merely labels something with a number.
  ///
  /// An irregular plural settles it on its own — "people" is never a verb.
  /// A regular `-s` is ambiguous ("steps", "opens", "matches"), so it also
  /// has to sit after a number that is in count position.
  static bool _isCountedNoun(String noun, String value, String placeholder) {
    if (_irregularPlurals.contains(noun.toLowerCase())) return true;
    if (!_looksPlural(noun)) return false;
    return _inCountPosition(value, placeholder);
  }

  /// Whether the `{placeholder}` occurrence in [value] is positioned to count
  /// what follows it.
  ///
  /// True when the number opens its phrase (nothing before it, or an ICU
  /// brace, or punctuation) or follows a word that introduces a quantity
  /// ([_introducers]). False when a bare content word precedes it, because
  /// then the number labels *that* word — "Goal {goal}", "step {step}",
  /// "Level {level}" — and governs nothing to its right.
  static bool _inCountPosition(String value, String placeholder) {
    final before = _wordBefore(value, placeholder);
    return before == null || _introducers.contains(before.toLowerCase());
  }

  /// The bare word immediately preceding the `{placeholder}` occurrence in
  /// [value], or `null` when the placeholder opens its phrase.
  ///
  /// Mirrors [_wordAfter]: exactly one run of spaces, then letters. Anything
  /// else before the placeholder — a brace, a colon, a digit, the start of
  /// the string — yields `null`, which reads as "nothing is being labelled".
  static String? _wordBefore(String value, String placeholder) {
    final match = RegExp(
      '\\{\\s*${RegExp.escape(placeholder)}\\s*(?:,[^{}]*)?\\}',
    ).firstMatch(value);
    if (match == null) return null;

    var i = match.start;
    var sawSpace = false;
    while (i > 0 && value[i - 1] == ' ') {
      sawSpace = true;
      i--;
    }
    if (!sawSpace) return null;

    final end = i;
    while (i > 0 && _isLetter(value.codeUnitAt(i - 1))) {
      i--;
    }
    if (i == end) return null;
    return value.substring(i, end);
  }

  /// Words after which a number is counting something.
  ///
  /// Prepositions, conjunctions, determiners and degree adverbs, plus the
  /// verbs of having, finding and acting that introduce a quantity in UI
  /// copy. The list is what keeps a real defect firing once step 4 is in
  /// place; anything not on it is treated as a noun the number labels, which
  /// is the quiet side of the trade.
  static const Set<String> _introducers = {
    // prepositions and conjunctions
    'of', 'in', 'on', 'at', 'to', 'from', 'by', 'with', 'for', 'and', 'or',
    'per', 'than', 'that', 'into', 'onto', 'via', 'plus', 'minus', 'across',
    'among', 'between', 'over', 'under', 'about', 'after', 'before', 'within',
    'but', 'nor', 'as',
    // determiners and quantifiers
    'the', 'a', 'an', 'all', 'any', 'some', 'no', 'these', 'those', 'another',
    'every', 'both', 'my', 'your', 'their', 'our', 'its', 'this',
    // degree and focus adverbs
    'only', 'just', 'still', 'now', 'nearly', 'almost', 'least', 'most',
    'up', 'more', 'less', 'fewer', 'around', 'roughly', 'approximately',
    'exactly', 'already', 'also', 'then', 'first', 'last', 'next', 'other',
    // verbs that introduce a quantity
    'is', 'are', 'was', 'were', 'be', 'been', 'has', 'have', 'had',
    'contains', 'contain', 'includes', 'include', 'shows', 'show', 'found',
    'find', 'finds', 'added', 'add', 'adds', 'removed', 'remove', 'removes',
    'deleted', 'delete', 'selected', 'select', 'sent', 'send', 'got', 'get',
    'gets', 'made', 'make', 'saved', 'save', 'loaded', 'load', 'imported',
    'import', 'skipped', 'skip', 'completed', 'complete', 'left', 'needs',
    'need', 'takes', 'take', 'costs', 'cost', 'gives', 'give', 'earned',
    'earn', 'wrote', 'write', 'read', 'says', 'say',
  };

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
  ///
  /// Shape alone is not enough for the regular case, because a third-person
  /// singular verb wears the same `-s`; [_isCountedNoun] adds the position
  /// test that separates them.
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
