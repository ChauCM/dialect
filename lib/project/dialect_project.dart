import 'dart:io';

import 'package:path/path.dart' as p;

import '../arb/arb_file.dart';
import '../arb/arb_parser.dart';
import '../config/dialect_config.dart';
import '../glossary/glossary_loader.dart';

/// A loaded Dialect project: parsed `dialect.yaml` plus the source ARB
/// and every translation ARB.
///
/// Most v1.0 commands (`check`, `sync`, `status`) take a [DialectProject]
/// as input and never touch the filesystem themselves. The two
/// exceptions are `init` (creates the structure) and the report
/// formatter (re-reads a file when computing a `file:line` for an
/// orphan).
class DialectProject {
  DialectProject({
    required this.root,
    required this.config,
    required this.source,
    required this.translations,
    Glossary? glossary,
  }) : glossary = glossary ?? Glossary.empty();

  /// Repo-relative or absolute path to the directory containing
  /// `dialect/`. `path.join(root, 'dialect', …)` is the rule.
  final String root;

  /// Parsed `dialect/dialect.yaml`.
  final DialectConfig config;

  /// Parsed `dialect/source/<source_locale>.arb`.
  final ArbFile source;

  /// Parsed `dialect/translations/<locale>.arb` for every configured
  /// target locale. Keys may be missing if a translation file doesn't
  /// exist yet — the check rule [`missing_keys`] surfaces that.
  final Map<String, ArbFile> translations;

  /// Parsed `dialect/glossary.yaml`. Empty (but non-null) when the file
  /// is missing — the glossary check rule no-ops in that case.
  final Glossary glossary;

  /// Load the project rooted at [root] (the directory that contains
  /// `dialect/`). Throws [FileSystemException] if the directory layout
  /// is wrong; throws [FormatException] from the parsers if any file is
  /// malformed.
  ///
  /// A missing translation file is NOT an error here — `missing_keys`
  /// reports it. We synthesize an empty [ArbFile] for the locale so
  /// downstream rules don't have to null-check.
  static DialectProject load(String root) {
    final dialectDir = Directory(p.join(root, 'dialect'));
    if (!dialectDir.existsSync()) {
      throw FileSystemException('No dialect/ directory found in $root');
    }

    final configFile = File(p.join(dialectDir.path, 'dialect.yaml'));
    if (!configFile.existsSync()) {
      throw FileSystemException('Missing dialect/dialect.yaml in $root');
    }
    final config = DialectConfig.parse(configFile.readAsStringSync());

    final sourcePath = p.join(
      dialectDir.path,
      'source',
      '${config.sourceLocale}.arb',
    );
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw FileSystemException(
        'Missing source ARB at $sourcePath '
        '(expected because source_locale is `${config.sourceLocale}` in '
        'dialect.yaml).',
      );
    }
    final source = ArbParser.parse(
      sourceFile.readAsStringSync(),
      sourcePath: sourcePath,
    );

    final translations = <String, ArbFile>{};
    for (final locale in config.targetLocales) {
      final tPath = p.join(dialectDir.path, 'translations', '$locale.arb');
      final f = File(tPath);
      if (!f.existsSync()) {
        translations[locale] = ArbFile(
          locale: locale,
          entries: const [],
          sourcePath: tPath,
        );
        continue;
      }
      translations[locale] = ArbParser.parse(
        f.readAsStringSync(),
        sourcePath: tPath,
      );
    }

    final glossary = Glossary.loadFromProjectRoot(root);

    return DialectProject(
      root: root,
      config: config,
      source: source,
      translations: translations,
      glossary: glossary,
    );
  }
}
