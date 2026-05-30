import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../adapters/arb_adapter.dart';
import '../adapters/json_adapter.dart';
import '../arb/arb_file.dart';
import '../config/dialect_config.dart';
import '../project/dialect_project.dart';

/// Builds a `dialect-bundle/1` bundle from a loaded project — pure, no I/O.
/// The transport (filesystem, S3, …) consumes [Bundle]; the version is a
/// deterministic function of content, so identical translations always
/// produce the same [Bundle.version]. See `dialect/spec/bundle.md`.
class BundleBuilder {
  const BundleBuilder._();

  static const String schema = 'dialect-bundle/1';

  /// Build the bundle for [env]. [createdAt] (ISO-8601 UTC) and [generator]
  /// (`dialect <version>`) are informational manifest fields and are
  /// deliberately *not* inputs to the version hash, so re-publishing
  /// identical content is deterministic.
  static Bundle build(
    DialectProject project,
    PublishEnvConfig env, {
    required String createdAt,
    required String generator,
  }) {
    final stripPlurals = env.format == 'flat-json';
    // A throwaway platform config so the bundle reuses the exact same
    // namespace filter + metadata strip as `dialect sync`.
    final filter = PlatformConfig(
      name: env.name,
      output: '',
      format: env.format,
      namespaces: env.namespaces,
    );

    final files = <BundleLocale>[];
    void add(String locale, ArbFile arb, {required bool isSource}) {
      final prepared = ArbAdapter.prepare(
        arb,
        platform: filter,
        isSource: isSource,
        source: isSource ? null : project.source,
      );
      final content = JsonAdapter.encode(
        prepared.arb,
        stripPlurals: stripPlurals,
      ).content;
      files.add(
        BundleLocale(
          locale: locale,
          file: '$locale.json',
          content: content,
          sha256: sha256.convert(utf8.encode(content)).toString(),
          keys: prepared.arb.entries.length,
        ),
      );
    }

    add(project.config.sourceLocale, project.source, isSource: true);
    for (final locale in project.config.targetLocales) {
      final arb =
          project.translations[locale] ??
          ArbFile(locale: locale, entries: const []);
      add(locale, arb, isSource: false);
    }
    files.sort((a, b) => a.locale.compareTo(b.locale));

    final version = _deriveVersion(
      env.format,
      project.config.sourceLocale,
      files,
    );

    return Bundle(
      version: version,
      format: env.format,
      sourceLocale: project.config.sourceLocale,
      locales: files,
      createdAt: createdAt,
      generator: generator,
    );
  }

  /// `sha256-16` of a canonical string over content only (format, source
  /// locale, and each locale's file hash) — per `dialect/spec/bundle.md`.
  static String _deriveVersion(
    String format,
    String sourceLocale,
    List<BundleLocale> sortedLocales,
  ) {
    final buf = StringBuffer()
      ..write('$schema\n')
      ..write('format:$format\n')
      ..write('source:$sourceLocale\n');
    for (final l in sortedLocales) {
      buf.write('${l.locale} ${l.sha256}\n');
    }
    return sha256
        .convert(utf8.encode(buf.toString()))
        .toString()
        .substring(0, 16);
  }
}

/// An immutable, content-addressed bundle ready to upload.
class Bundle {
  Bundle({
    required this.version,
    required this.format,
    required this.sourceLocale,
    required this.locales,
    required this.createdAt,
    required this.generator,
  });

  final String version;
  final String format;
  final String sourceLocale;
  final List<BundleLocale> locales;
  final String createdAt;
  final String generator;

  /// Prefix-relative directory holding the immutable objects.
  String get versionDir => 'b/$version';

  /// The immutable bundle manifest (`b/<version>/manifest.json`).
  String get manifestJson =>
      '${const JsonEncoder.withIndent('  ').convert({
        'schema': BundleBuilder.schema,
        'bundle_version': version,
        'format': format,
        'source_locale': sourceLocale,
        'locales': [
          for (final l in locales) {'locale': l.locale, 'file': l.file, 'sha256': l.sha256, 'keys': l.keys},
        ],
        'created_at': createdAt,
        'generator': generator,
      })}\n';

  /// The channel head (`<prefix>/manifest.json`) pointing at this version.
  String get channelHeadJson =>
      '${const JsonEncoder.withIndent('  ').convert({'schema': BundleBuilder.schema, 'current': version, 'manifest': '$versionDir/manifest.json'})}\n';
}

/// One locale's file within a bundle.
class BundleLocale {
  BundleLocale({
    required this.locale,
    required this.file,
    required this.content,
    required this.sha256,
    required this.keys,
  });

  final String locale;
  final String file;
  final String content;
  final String sha256;
  final int keys;
}
