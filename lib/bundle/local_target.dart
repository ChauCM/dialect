import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'bundle_builder.dart';

/// Filesystem transport for `target: local` — writes a [Bundle] under a
/// prefix directory and reads it back for `dialect pull`. The same on-disk
/// shape an S3/R2 target uploads (`dialect/spec/bundle.md`); the S3 target
/// is the identical protocol over HTTP.
class LocalTarget {
  const LocalTarget._();

  /// Write [bundle] under [baseDir]. Immutable objects (`b/<version>/…`) are
  /// written only if absent — re-publishing identical content is a no-op.
  /// The channel head is written last (after every immutable object), so a
  /// reader never sees a head pointing at an incomplete bundle.
  static BundleWriteResult write(String baseDir, Bundle bundle) {
    final versionDir = p.join(baseDir, 'b', bundle.version);
    final manifestPath = p.join(versionDir, 'manifest.json');
    final alreadyPublished = File(manifestPath).existsSync();

    final written = <String>[];
    if (!alreadyPublished) {
      Directory(versionDir).createSync(recursive: true);
      File(manifestPath).writeAsStringSync(bundle.manifestJson);
      written.add(p.join(bundle.versionDir, 'manifest.json'));
      for (final l in bundle.locales) {
        File(p.join(versionDir, l.file)).writeAsStringSync(l.content);
        written.add(p.join(bundle.versionDir, l.file));
      }
    }

    final headPath = p.join(baseDir, 'manifest.json');
    final head = bundle.channelHeadJson;
    final headChanged =
        !File(headPath).existsSync() ||
        File(headPath).readAsStringSync() != head;
    if (headChanged) {
      Directory(baseDir).createSync(recursive: true);
      File(headPath).writeAsStringSync(head);
    }

    return BundleWriteResult(
      alreadyPublished: alreadyPublished,
      filesWritten: written,
      headUpdated: headChanged,
    );
  }

  /// Read and verify the published bundle under [baseDir]. Throws
  /// [FormatException] on a missing/malformed manifest or a SHA-256
  /// mismatch (a corrupt object must never reach a deploy).
  static PulledBundle read(String baseDir) {
    final headFile = File(p.join(baseDir, 'manifest.json'));
    if (!headFile.existsSync()) {
      throw FormatException('No bundle channel head at ${headFile.path}.');
    }
    final head = _decodeObject(headFile.readAsStringSync(), headFile.path);
    final manifestRel = head['manifest'];
    if (manifestRel is! String) {
      throw const FormatException('Channel head is missing `manifest`.');
    }
    final manifestFile = File(p.join(baseDir, manifestRel));
    if (!manifestFile.existsSync()) {
      throw FormatException('Bundle manifest missing at ${manifestFile.path}.');
    }
    final manifest = _decodeObject(
      manifestFile.readAsStringSync(),
      manifestFile.path,
    );
    final versionDir = p.dirname(manifestFile.path);

    final locales = <PulledLocale>[];
    final rawLocales = manifest['locales'];
    if (rawLocales is! List) {
      throw const FormatException('Bundle manifest `locales` must be a list.');
    }
    for (final entry in rawLocales) {
      if (entry is! Map) continue;
      final locale = entry['locale'] as String;
      final file = entry['file'] as String;
      final expected = entry['sha256'] as String;
      final content = File(p.join(versionDir, file)).readAsStringSync();
      final actual = sha256.convert(utf8.encode(content)).toString();
      if (actual != expected) {
        throw FormatException(
          'Bundle integrity check failed for `$locale` ($file): expected '
          'sha256 $expected, got $actual.',
        );
      }
      locales.add(
        PulledLocale(
          locale: locale,
          file: file,
          content: content,
          keys: entry['keys'] is int ? entry['keys'] as int : null,
        ),
      );
    }

    return PulledBundle(
      version:
          manifest['bundle_version'] as String? ?? head['current'] as String,
      format: manifest['format'] as String? ?? 'icu-json',
      locales: locales,
    );
  }

  static Map<String, Object?> _decodeObject(String text, String path) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('$path is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException('$path must be a JSON object.');
    }
    return decoded;
  }
}

class BundleWriteResult {
  BundleWriteResult({
    required this.alreadyPublished,
    required this.filesWritten,
    required this.headUpdated,
  });

  /// True when the version dir already existed — no immutable objects were
  /// (re-)written.
  final bool alreadyPublished;
  final List<String> filesWritten;
  final bool headUpdated;
}

class PulledBundle {
  PulledBundle({
    required this.version,
    required this.format,
    required this.locales,
  });
  final String version;
  final String format;
  final List<PulledLocale> locales;
}

class PulledLocale {
  PulledLocale({
    required this.locale,
    required this.file,
    required this.content,
    this.keys,
  });
  final String locale;
  final String file;
  final String content;
  final int? keys;
}
