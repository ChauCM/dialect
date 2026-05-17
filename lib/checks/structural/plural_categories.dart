import '../../arb/icu_message.dart';
import '../../project/dialect_project.dart';
import '../cldr_categories.dart';
import '../rule.dart';

/// When the source value is an ICU plural expression, every translation
/// must cover all CLDR categories the locale requires, **in addition
/// to** any `=N` exact-match cases.
///
/// This is the rule that caught Codex 5.3's Arabic-itemCount defect in
/// `_validation/COMPARISON.md`: it kept only `=0`, `=1`, `other`, which
/// renders incorrectly for counts 2, 3, 4, 11, 100+. Real-world bug
/// fixture; see `test/checks/structural/plural_categories_test.dart`.
class PluralCategoriesRule extends Rule {
  const PluralCategoriesRule();

  @override
  String get name => 'plural_categories';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    for (final src in project.source.entries) {
      // Only fires when the source value is actually a plural expression.
      if (IcuMessage.extractPluralCategories(src.value) == null) continue;

      for (final entry in project.translations.entries) {
        final locale = entry.key;
        final arb = entry.value;
        final translated = arb.entryFor(src.key);
        if (translated == null) continue; // missing_keys handles this

        final required = requiredCldrCategories(locale);
        if (required == null) {
          // Unknown locale — emit a warning so the user knows the check
          // didn't run, rather than silently skipping.
          issues.add(
            Issue(
              severity: IssueSeverity.warning,
              ruleName: name,
              message:
                  'Plural-categories check skipped: locale `$locale` '
                  'is not in Dialect\'s CLDR table.',
              locale: locale,
              key: src.key,
              file: arb.sourcePath,
              line: arb.entryLines[src.key],
              hint:
                  'Add `$locale` to lib/checks/cldr_categories.dart if '
                  'you want this check enforced, or ignore — translations '
                  'still ship.',
            ),
          );
          continue;
        }

        final present =
            IcuMessage.extractPluralCategories(translated.value)?.toSet() ??
            <String>{};
        // CLDR categories only — `=N` mirrors are tracked but not required.
        final presentCategories = present
            .where((c) => !c.startsWith('='))
            .toSet();
        final missing = required.difference(presentCategories);

        if (missing.isEmpty) continue;

        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message:
                'Plural for key `${src.key}` is missing CLDR '
                'categor${missing.length == 1 ? "y" : "ies"} '
                '${missing.map((c) => "`$c`").join(", ")} '
                'required by locale `$locale`.',
            locale: locale,
            key: src.key,
            file: arb.sourcePath,
            line: arb.entryLines[src.key],
            hint:
                'Locale `$locale` needs all of '
                '${required.map((c) => "`$c`").join(", ")}. CLDR categories '
                'are required IN ADDITION TO any `=N` exact-match cases '
                'you copied from source — they\'re not a substitute for '
                'each other.',
          ),
        );
      }
    }

    return issues;
  }
}
