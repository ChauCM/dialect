import 'package:yaml/yaml.dart' as yaml;

/// Typed view of `dialect.yaml`. M4 only reads `source_locale` and
/// `target_locales`. M5 will extend this with `platforms`,
/// `length_ratio`, and the `project` block; the parser already preserves
/// unknown top-level keys in [extras] so M5 doesn't need to rewrite
/// loading.
class DialectConfig {
  DialectConfig({
    required this.sourceLocale,
    required this.targetLocales,
    this.extras = const {},
  });

  /// Source language tag (e.g. `en`).
  final String sourceLocale;

  /// Translation targets (e.g. `[es, ja, ar]`). Empty after `dialect
  /// init` — the user fills this in before their first `dialect check`.
  final List<String> targetLocales;

  /// Other top-level keys from `dialect.yaml`, preserved for M5+.
  final Map<String, Object?> extras;

  /// Parse a YAML string. Throws [FormatException] on missing
  /// `source_locale`, malformed `target_locales`, or non-map root.
  static DialectConfig parse(String content) {
    final root = yaml.loadYaml(content);
    if (root is! yaml.YamlMap) {
      throw const FormatException(
        'dialect.yaml must be a YAML map at the top level.',
      );
    }

    final sourceLocale = root['source_locale'];
    if (sourceLocale is! String || sourceLocale.isEmpty) {
      throw const FormatException(
        'dialect.yaml is missing a `source_locale:` field (e.g. `en`).',
      );
    }

    final targetLocales = <String>[];
    final raw = root['target_locales'];
    if (raw == null) {
      // Allow missing — equivalent to empty list (fresh `dialect init`).
    } else if (raw is yaml.YamlList) {
      for (final v in raw) {
        if (v is! String) {
          throw FormatException(
            'target_locales must be a list of locale strings; '
            'got ${v.runtimeType}.',
          );
        }
        targetLocales.add(v);
      }
    } else {
      throw FormatException(
        'target_locales must be a list, got ${raw.runtimeType}.',
      );
    }

    final extras = <String, Object?>{};
    for (final entry in root.entries) {
      final k = entry.key;
      if (k is! String) continue;
      if (k == 'source_locale' || k == 'target_locales') continue;
      extras[k] = _unwrap(entry.value);
    }

    return DialectConfig(
      sourceLocale: sourceLocale,
      targetLocales: targetLocales,
      extras: extras,
    );
  }

  static Object? _unwrap(Object? v) {
    if (v is yaml.YamlMap) {
      return {
        for (final e in v.entries)
          if (e.key is String) (e.key as String): _unwrap(e.value),
      };
    }
    if (v is yaml.YamlList) {
      return [for (final item in v) _unwrap(item)];
    }
    return v;
  }
}
