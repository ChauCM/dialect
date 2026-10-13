import '../../project/dialect_project.dart';
import '../rule.dart';

/// Every source key must exist (with a non-null value) in every target
/// locale's ARB file. Missing keys become untranslated holes in the
/// shipped app.
///
/// A locale listed under `partial_locales:` in `dialect.yaml` is still being
/// filled in, so a hole there is expected. It gets one [IssueSeverity.info]
/// progress line instead of one error per key, which never fails a run. When
/// such a locale has caught up, the line says it can be made complete, so the
/// marker does not outlive its purpose and quietly hide a regression.
class MissingKeysRule extends Rule {
  const MissingKeysRule();

  @override
  String get name => 'missing_keys';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    final sourceKeys = project.source.entries.map((e) => e.key).toSet();
    final partial = project.config.partialLocales.toSet();

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      final arb = entry.value;
      final present = arb.entries.map((e) => e.key).toSet();
      final missing = sourceKeys.difference(present);

      if (partial.contains(locale)) {
        final total = sourceKeys.length;
        final done = total - missing.length;
        final complete = missing.isEmpty;
        issues.add(
          Issue(
            severity: IssueSeverity.info,
            ruleName: name,
            message: complete
                ? '$locale: ${_n(done)} of ${_n(total)} keys translated — '
                      'complete; remove `$locale` from partial_locales in '
                      'dialect.yaml to make it a fully checked locale.'
                : '$locale: ${_n(done)} of ${_n(total)} keys translated',
            locale: locale,
            file: arb.sourcePath,
            hint: complete
                ? null
                : '`$locale` is listed in partial_locales, so its '
                      '${_n(missing.length)} missing keys are not reported '
                      'individually and do not fail --strict. Every other '
                      'rule still applies to the keys that exist.',
          ),
        );
        continue;
      }

      for (final key in missing) {
        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message: 'Missing translation for key `$key`.',
            locale: locale,
            key: key,
            file: arb.sourcePath,
            // No line — the key isn't in this file yet.
            hint:
                'Run `dialect translate` to backfill missing keys, '
                'or add the entry to ${arb.sourcePath} by hand.',
          ),
        );
      }
    }

    return issues;
  }

  /// `2520` -> `2,520`.
  static String _n(int n) {
    final digits = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
