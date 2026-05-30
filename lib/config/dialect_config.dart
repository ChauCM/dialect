import 'package:yaml/yaml.dart' as yaml;

/// Typed view of `dialect.yaml`. M4 reads `source_locale` /
/// `target_locales`; M5 adds `platforms`. The `length_ratio` block and
/// the `project` block lands when M8 needs them — for now they're
/// preserved verbatim in [extras].
class DialectConfig {
  DialectConfig({
    required this.sourceLocale,
    required this.targetLocales,
    this.platforms = const {},
    this.publishEnvs = const {},
    this.extras = const {},
  });

  /// Source language tag (e.g. `en`).
  final String sourceLocale;

  /// Translation targets (e.g. `[es, ja, ar]`). Empty after `dialect
  /// init` — the user fills this in before their first `dialect check`.
  final List<String> targetLocales;

  /// Per-platform output config keyed by platform name (`flutter`,
  /// `ios`, `android`, `backend`). v1.0 ships only the `arb` format
  /// adapter (M5 `dialect sync`); other formats are stored verbatim
  /// here for M11 / v1.1 to consume.
  final Map<String, PlatformConfig> platforms;

  /// Per-environment publish config keyed by env name (`production`,
  /// `staging`). Read by `dialect publish` / `dialect pull` (v1.2). Empty
  /// when no `publish:` block is configured.
  final Map<String, PublishEnvConfig> publishEnvs;

  /// Other top-level keys from `dialect.yaml`, preserved verbatim.
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

    final platforms = <String, PlatformConfig>{};
    final rawPlatforms = root['platforms'];
    if (rawPlatforms != null) {
      if (rawPlatforms is! yaml.YamlMap) {
        throw FormatException(
          'platforms must be a map, got ${rawPlatforms.runtimeType}.',
        );
      }
      for (final entry in rawPlatforms.entries) {
        final platformName = entry.key;
        if (platformName is! String) continue;
        final platformValue = entry.value;
        if (platformValue is! yaml.YamlMap) {
          throw FormatException(
            'platforms.$platformName must be a map, got '
            '${platformValue.runtimeType}.',
          );
        }
        platforms[platformName] = PlatformConfig._fromYaml(
          platformName,
          platformValue,
        );
      }
    }

    final publishEnvs = <String, PublishEnvConfig>{};
    final rawPublish = root['publish'];
    if (rawPublish != null) {
      if (rawPublish is! yaml.YamlMap) {
        throw FormatException(
          'publish must be a map of <env> blocks, got '
          '${rawPublish.runtimeType}.',
        );
      }
      for (final entry in rawPublish.entries) {
        final envName = entry.key;
        if (envName is! String) continue;
        final envValue = entry.value;
        if (envValue is! yaml.YamlMap) {
          throw FormatException(
            'publish.$envName must be a map, got ${envValue.runtimeType}.',
          );
        }
        publishEnvs[envName] = PublishEnvConfig._fromYaml(envName, envValue);
      }
    }

    final extras = <String, Object?>{};
    for (final entry in root.entries) {
      final k = entry.key;
      if (k is! String) continue;
      if (k == 'source_locale' ||
          k == 'target_locales' ||
          k == 'platforms' ||
          k == 'publish') {
        continue;
      }
      extras[k] = _unwrap(entry.value);
    }

    return DialectConfig(
      sourceLocale: sourceLocale,
      targetLocales: targetLocales,
      platforms: platforms,
      publishEnvs: publishEnvs,
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

/// One platform's sync configuration. Read from `platforms.<name>` in
/// `dialect.yaml`. v1.0 honors only `format: arb`; other formats are
/// parsed and stored verbatim, so a future v1.1 adapter can pick them up
/// without re-parsing.
class PlatformConfig {
  PlatformConfig({
    required this.name,
    required this.output,
    required this.format,
    this.namespaces = const [],
  });

  /// Platform key from the YAML map, e.g. `flutter`, `ios`, `backend`.
  final String name;

  /// Output directory, relative to the project root. The sync command
  /// resolves it as `path.join(project.root, output)`. Not relative to
  /// `cwd` — sync must work the same whether the user runs it from the
  /// repo root or `dialect sync /path/to/proj`.
  final String output;

  /// Format adapter name. v1.0: `arb`. v1.1 adds `apple-strings`,
  /// `android-xml`, `flat-json`, `icu-json`. Unknown formats are not
  /// rejected here — the sync command surfaces them with a "this format
  /// lands in v1.1" hint.
  final String format;

  /// Namespace filter. Only keys whose prefix (before the first `.`)
  /// appears in this list are synced to this platform. Empty list = no
  /// filtering (every key syncs).
  final List<String> namespaces;

  static PlatformConfig _fromYaml(String name, yaml.YamlMap raw) {
    final output = raw['output'];
    if (output is! String || output.isEmpty) {
      throw FormatException(
        'platforms.$name.output must be a non-empty string '
        '(e.g. `lib/l10n/`).',
      );
    }
    final format = raw['format'];
    if (format is! String || format.isEmpty) {
      throw FormatException(
        'platforms.$name.format must be a non-empty string '
        '(e.g. `arb`, `apple-strings`, `flat-json`).',
      );
    }
    final namespaces = <String>[];
    final rawNs = raw['namespaces'];
    if (rawNs is yaml.YamlList) {
      for (final v in rawNs) {
        if (v is String) namespaces.add(v);
      }
    } else if (rawNs != null) {
      throw FormatException(
        'platforms.$name.namespaces must be a list of strings.',
      );
    }
    return PlatformConfig(
      name: name,
      output: output,
      format: format,
      namespaces: namespaces,
    );
  }
}

/// One environment's publish config, read from `publish.<env>` in
/// `dialect.yaml`. Drives `dialect publish` / `dialect pull` (v1.2) — see
/// `dialect/spec/bundle.md`. Credentials are NEVER read from here; the
/// `s3` target uses the standard AWS env vars / profile.
class PublishEnvConfig {
  PublishEnvConfig({
    required this.name,
    required this.target,
    this.path,
    this.bucket,
    this.prefix = '',
    this.format = 'icu-json',
    this.namespaces = const [],
    this.manifestUrl,
    this.output,
  });

  /// Env key from the YAML map, e.g. `production`, `staging`.
  final String name;

  /// `local` (filesystem) or `s3` (S3-compatible: AWS, R2, MinIO).
  final String target;

  /// Filesystem prefix for `target: local`.
  final String? path;

  /// Bucket name for `target: s3`.
  final String? bucket;

  /// Key prefix within the bucket / under [path]. Defaults to `''`.
  final String prefix;

  /// Bundle format: `icu-json` (default) or `flat-json`.
  final String format;

  /// Namespace filter — empty means every key. Same semantics as
  /// `platforms.<p>.namespaces`.
  final List<String> namespaces;

  /// Public URL of the channel head, used by `dialect pull` and by
  /// backends reading at startup.
  final String? manifestUrl;

  /// Directory `dialect pull` writes the fetched locale files into.
  final String? output;

  static PublishEnvConfig _fromYaml(String name, yaml.YamlMap raw) {
    final target = raw['target'];
    if (target is! String || target.isEmpty) {
      throw FormatException(
        'publish.$name.target must be a non-empty string (`local` or `s3`).',
      );
    }
    if (target == 'local' && (raw['path'] is! String || raw['path'] == '')) {
      throw FormatException(
        'publish.$name.path is required for `target: local` '
        '(e.g. `dist/locales/`).',
      );
    }
    if (target == 's3' && (raw['bucket'] is! String || raw['bucket'] == '')) {
      throw FormatException(
        'publish.$name.bucket is required for `target: s3`.',
      );
    }
    final format = raw['format'];
    if (format != null && format != 'icu-json' && format != 'flat-json') {
      throw FormatException(
        'publish.$name.format must be `icu-json` or `flat-json`.',
      );
    }
    final namespaces = <String>[];
    final rawNs = raw['namespaces'];
    if (rawNs is yaml.YamlList) {
      for (final v in rawNs) {
        if (v is String) namespaces.add(v);
      }
    } else if (rawNs != null) {
      throw FormatException(
        'publish.$name.namespaces must be a list of strings.',
      );
    }
    return PublishEnvConfig(
      name: name,
      target: target,
      path: raw['path'] as String?,
      bucket: raw['bucket'] as String?,
      prefix: raw['prefix'] is String ? raw['prefix'] as String : '',
      format: format is String ? format : 'icu-json',
      namespaces: namespaces,
      manifestUrl: raw['manifest_url'] as String?,
      output: raw['output'] as String?,
    );
  }
}
