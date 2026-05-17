/// CLDR plural categories required per locale, as of CLDR 44 (2024).
///
/// Used by `lib/checks/structural/plural_categories.dart` to validate
/// that translations of a plural ICU expression cover all the categories
/// the locale requires.
///
/// Locale matching is BCP-47 language-subtag first: `pt-BR` matches the
/// `pt` entry; an unmatched locale returns `null` and the plural-category
/// check is skipped with a soft-mode hint that the table doesn't cover
/// the locale. Add new entries here as Dialect users adopt new locales.
library;

/// Categories required by `cardinal` plural rules.
///
/// `=N` exact-match cases are independent of CLDR categories — both are
/// required by the convention (see `templates/dialect.yaml` plural
/// section). The check rule enforces "every required category appears,
/// in addition to any `=N` mirrors."
const Map<String, Set<String>> cldrPluralCategories = {
  // Single-form locales: `other` covers everything.
  'ja': {'other'},
  'ko': {'other'},
  'th': {'other'},
  'vi': {'other'},
  'zh': {'other'},
  'id': {'other'},
  'ms': {'other'},
  'tr': {'other'}, // technically `other`, plus optional `one`.
  // Two-form locales (English-like).
  'en': {'one', 'other'},
  'es': {'one', 'other'},
  'pt': {'one', 'other'},
  'it': {'one', 'other'},
  'de': {'one', 'other'},
  'nl': {'one', 'other'},
  'sv': {'one', 'other'},
  'da': {'one', 'other'},
  'no': {'one', 'other'},
  'fi': {'one', 'other'},
  'el': {'one', 'other'},
  'he': {'one', 'two', 'many', 'other'}, // Modern Hebrew
  // French: `one` covers 0 and 1.
  'fr': {'one', 'many', 'other'},

  // Slavic — multiple distinct stems.
  'ru': {'one', 'few', 'many', 'other'},
  'uk': {'one', 'few', 'many', 'other'},
  'pl': {'one', 'few', 'many', 'other'},
  'cs': {'one', 'few', 'many', 'other'},
  'sk': {'one', 'few', 'many', 'other'},

  // Arabic: full 6-form.
  'ar': {'zero', 'one', 'two', 'few', 'many', 'other'},
};

/// CLDR categories the [locale] requires, or `null` if Dialect's table
/// doesn't cover it. Tries the full tag first (`pt-BR`), then the
/// language subtag (`pt`).
Set<String>? requiredCldrCategories(String locale) {
  if (cldrPluralCategories.containsKey(locale)) {
    return cldrPluralCategories[locale];
  }
  final dash = locale.indexOf('-');
  if (dash > 0) {
    final lang = locale.substring(0, dash).toLowerCase();
    return cldrPluralCategories[lang];
  }
  return null;
}
