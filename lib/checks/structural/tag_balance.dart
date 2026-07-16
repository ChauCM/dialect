import '../../arb/icu_message.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Inline rich-text tags (`<b>…</b>`, `<j>…</j>`) must balance, and a
/// translation must carry the source key's tags in a single rendered
/// message.
///
/// The rich-text recipe (docs/platforms-frontend.md, "Rich text inside one
/// sentence"): a styled run inside a localized sentence is authored as an
/// inline HTML-style tag in the ARB value, passed through `gen_l10n` as
/// literal text, and rebuilt into spans by a small app-side helper from a
/// tag → style map. That helper can only rebuild what is well-formed, so:
///
/// - every open tag needs its close tag, properly nested;
/// - a translation must use the same tags, the same number of times, as its
///   source — a dropped `</b>` bolds the rest of the sentence, an invented
///   tag renders as literal `<x>` in the UI.
///
/// Tags may move freely (target-language word order wins). Counts are
/// compared over ONE rendered message, not the raw string, because an ICU
/// plural/select repeats its tags once per branch. A source
/// `{n, plural, =1{<b>..</b>} other{<b>..</b>}}` carries `<b>` twice in the
/// raw value, but a target locale with a single CLDR category (Vietnamese,
/// Japanese) correctly collapses to one `other` branch and carries it once.
/// Both render exactly one `<b>` run, so both are correct. Collapsing every
/// plural/select to its `other` branch (via [IcuMessage.flattenToOther])
/// before counting makes the comparison see what the user sees: the tags in
/// a single rendering. Balance is still enforced over the WHOLE raw value,
/// so a broken tag hiding in any branch is caught. Values without tags are
/// ignored.
class TagBalanceRule extends Rule {
  const TagBalanceRule();

  @override
  String get name => 'tag_balance';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  static final _tag = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)>');

  /// Tag-name counts of the OPENING tags when [value] is well-formed
  /// (balanced + properly nested), or null when it is not.
  static Map<String, int>? _tagCounts(String value) {
    final counts = <String, int>{};
    final stack = <String>[];
    for (final m in _tag.allMatches(value)) {
      final closing = m.group(1)!.isNotEmpty;
      final tag = m.group(2)!;
      if (closing) {
        if (stack.isEmpty || stack.removeLast() != tag) return null;
      } else {
        stack.add(tag);
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return stack.isEmpty ? counts : null;
  }

  /// Tag counts of ONE rendered message: every plural/select collapses to
  /// its `other` branch first, so branch multiplicity does not inflate the
  /// tally. Falls back to the raw value if the message has no `other` branch
  /// to flatten to (malformed ICU is another rule's problem, not this one's).
  static Map<String, int>? _renderedTagCounts(String value) {
    String rendered;
    try {
      rendered = IcuMessage.flattenToOther(value);
    } on FormatException {
      rendered = value;
    }
    return _tagCounts(rendered);
  }

  static String _describe(Map<String, int> counts) {
    if (counts.isEmpty) return 'no tags';
    final parts = counts.entries.map((e) => '${e.value}x <${e.key}>').toList()
      ..sort();
    return parts.join(', ');
  }

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    // Source first: a broken source can't anchor any translation. Balance is
    // checked over the whole raw value (any branch), counts over one render.
    final sourceCounts = <String, Map<String, int>>{};
    for (final src in project.source.entries) {
      if (_tagCounts(src.value) == null) {
        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message: 'Source value for `${src.key}` has unbalanced tags.',
            locale: project.config.sourceLocale,
            key: src.key,
            file: project.source.sourcePath,
            line: project.source.entryLines[src.key],
            hint:
                'Every <tag> needs a matching </tag>, properly nested. '
                'See the rich-text recipe in the Dialect docs.',
          ),
        );
        continue;
      }
      sourceCounts[src.key] = _renderedTagCounts(src.value)!;
    }

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      if (locale == project.config.sourceLocale) continue;
      final arb = entry.value;
      for (final t in arb.entries) {
        final expected = sourceCounts[t.key];
        if (expected == null) continue; // missing/broken source covers it
        if (_tagCounts(t.value) == null) {
          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message: 'Translation for `${t.key}` has unbalanced tags.',
              locale: locale,
              key: t.key,
              file: arb.sourcePath,
              line: arb.entryLines[t.key],
              hint:
                  'Every <tag> needs a matching </tag>, properly nested. '
                  'The source renders ${_describe(expected)}.',
            ),
          );
          continue;
        }
        final actual = _renderedTagCounts(t.value)!;
        if (expected.isEmpty && actual.isEmpty) continue;
        if (!_sameCounts(expected, actual)) {
          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message:
                  'Translation for `${t.key}` renders ${_describe(actual)}; '
                  'the source renders ${_describe(expected)}.',
              locale: locale,
              key: t.key,
              file: arb.sourcePath,
              line: arb.entryLines[t.key],
              hint:
                  'A translation renders the same tags as its source — move '
                  'them to the target language\'s word order, but never add, '
                  'drop, or rename them. A plural counts once per rendering, '
                  'so a single-category locale (vi, ja) collapses its '
                  'branches without dropping a tag.',
            ),
          );
        }
      }
    }
    return issues;
  }

  static bool _sameCounts(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
