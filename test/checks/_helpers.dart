import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/config/dialect_config.dart';
import 'package:dialect/project/dialect_project.dart';

/// Build an in-memory [DialectProject] for unit testing rules without
/// hitting the filesystem. `root` defaults to `<test>` purely so the
/// formatter has something to display in error paths.
DialectProject project({
  String sourceLocale = 'en',
  required List<String> targetLocales,
  required ArbFile source,
  Map<String, ArbFile> translations = const {},
  String root = '<test>',
}) {
  return DialectProject(
    root: root,
    config: DialectConfig(
      sourceLocale: sourceLocale,
      targetLocales: targetLocales,
    ),
    source: source,
    translations: translations,
  );
}

/// Tiny helper for assembling an ARB with structured fields. Each
/// `entry` is a `(key, value, [metadata])` triple via [ArbEntry].
ArbFile arb({
  required String locale,
  List<ArbEntry> entries = const [],
  Map<String, ArbMetadata> orphans = const {},
  String? sourcePath,
}) {
  return ArbFile(
    locale: locale,
    entries: entries,
    orphanMetadata: orphans,
    sourcePath: sourcePath,
  );
}
