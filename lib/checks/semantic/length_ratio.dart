import '../../arb/arb_file.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Warn when a translation is suspiciously much shorter or longer than
/// the source. Out-of-band lengths are a strong signal of a truncated
/// translation, a swap-bug (wrong locale's text), or an AI that
/// hallucinated extra prose.
///
/// Per-locale [min, max] multipliers are read from `dialect.yaml`:
///
/// ```yaml
/// length_ratio:
///   ja: [0.4, 1.5]   # Japanese is consistently shorter
///   de: [0.5, 2.8]   # German is consistently longer
/// ```
///
/// Default for unlisted locales: `[0.3, 2.5]`. Very short source strings
/// (`< 8` chars) skip the check entirely — `"OK"` → `"はい"` is a 1x
/// ratio that's meaningless to police.
///
/// Severity is warning. `--strict-length` (separate from `--strict`)
/// promotes it to an error for CI gating.
class LengthRatioRule extends Rule {
  const LengthRatioRule();

  /// Default multiplier band when no per-locale override is set in
  /// `dialect.yaml`.
  static const List<double> defaultRange = [0.3, 2.5];

  /// Source strings shorter than this skip the check — short strings'
  /// ratios are too noisy to be a useful signal.
  static const int minSourceLength = 8;

  @override
  String get name => 'length_ratio';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];
    final overrides = _parseOverrides(project);

    final sourceByKey = <String, ArbEntry>{
      for (final e in project.source.entries) e.key: e,
    };

    for (final entry in project.translations.entries) {
      final locale = entry.key;
      if (locale == project.config.sourceLocale) continue;
      final arb = entry.value;
      final range = overrides[locale] ?? defaultRange;

      for (final t in arb.entries) {
        final src = sourceByKey[t.key];
        if (src == null) continue;
        if (src.value.length < minSourceLength) continue;
        if (t.value.isEmpty) continue; // empty_values rule covers this

        final ratio = t.value.length / src.value.length;
        if (ratio < range[0] || ratio > range[1]) {
          final direction = ratio < range[0] ? 'shorter' : 'longer';
          issues.add(
            Issue(
              severity: defaultSeverity,
              ruleName: name,
              message:
                  'Translation for `${t.key}` is '
                  '${ratio.toStringAsFixed(2)}× the source length — '
                  '$direction than the expected band '
                  '[${range[0]}, ${range[1]}].',
              locale: locale,
              key: t.key,
              file: arb.sourcePath,
              line: arb.entryLines[t.key],
              hint:
                  'Common causes: truncated UI text, wrong-locale paste, '
                  'or an AI hallucinating extra prose. If `$locale` legitimately '
                  'expands or contracts this much, add an override under '
                  '`length_ratio:` in dialect.yaml.',
            ),
          );
        }
      }
    }

    return issues;
  }

  /// Pull `length_ratio:` out of `DialectConfig.extras`. Tolerant of
  /// missing/partial data — anything that doesn't look like a 2-element
  /// numeric list is silently ignored (with a soft fallback to the
  /// default). Hard YAML errors would already have been caught at
  /// `DialectConfig.parse`.
  static Map<String, List<double>> _parseOverrides(DialectProject project) {
    final raw = project.config.extras['length_ratio'];
    if (raw is! Map<String, Object?>) return const {};
    final out = <String, List<double>>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is! List || v.length != 2) continue;
      final lo = _asDouble(v[0]);
      final hi = _asDouble(v[1]);
      if (lo == null || hi == null) continue;
      out[entry.key] = [lo, hi];
    }
    return out;
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    return null;
  }
}
