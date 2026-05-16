/// Keep `lib/templates/*.dart` in sync with the seed files under
/// `templates/`. Same pattern as `tool/sync_version.dart`.
///
/// The seed files at `templates/` are the canonical text:
///
///   templates/dialect.yaml       → lib/templates/dialect_yaml.dart
///                                  (const dialectYamlTemplate)
///   templates/glossary.yaml      → lib/templates/glossary_yaml.dart
///                                  (const glossaryYamlTemplate)
///   templates/source/en.arb      → lib/templates/source_arb.dart
///                                  (const sourceArbTemplate)
///   templates/gitignore_snippet  → lib/templates/gitignore_snippet.dart
///                                  (const gitignoreSnippet)
///
/// `dialect init` (M3) writes these constants verbatim to the user's
/// project. The canonical convention lives in source control as YAML/ARB
/// (reviewable in PRs, syntax-highlighted in editors); the Dart constants
/// are mechanical mirrors so the compiled binary doesn't need to ship the
/// seed files separately.
///
/// Usage:
///   `dart run tool/sync_templates.dart`         # regenerate lib/templates/
///   `dart run tool/sync_templates.dart --check`  # exit non-zero on drift
///
/// CI runs `--check` so a hand-edited `lib/templates/*.dart` fails the
/// build instead of silently winning over the canonical seed.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class _Mapping {
  const _Mapping({
    required this.source,
    required this.target,
    required this.constName,
  });
  final List<String> source;
  final List<String> target;
  final String constName;
}

const List<_Mapping> _mappings = [
  _Mapping(
    source: ['templates', 'dialect.yaml'],
    target: ['lib', 'templates', 'dialect_yaml.dart'],
    constName: 'dialectYamlTemplate',
  ),
  _Mapping(
    source: ['templates', 'glossary.yaml'],
    target: ['lib', 'templates', 'glossary_yaml.dart'],
    constName: 'glossaryYamlTemplate',
  ),
  _Mapping(
    source: ['templates', 'source', 'en.arb'],
    target: ['lib', 'templates', 'source_arb.dart'],
    constName: 'sourceArbTemplate',
  ),
  _Mapping(
    source: ['templates', 'gitignore_snippet'],
    target: ['lib', 'templates', 'gitignore_snippet.dart'],
    constName: 'gitignoreSnippet',
  ),
];

void main(List<String> arguments) {
  final check = arguments.contains('--check');
  final root = _repoRoot();
  final drifted = <String>[];

  for (final m in _mappings) {
    final srcPath = p.joinAll([root, ...m.source]);
    final tgtPath = p.joinAll([root, ...m.target]);
    final src = File(srcPath);
    if (!src.existsSync()) {
      stderr.writeln('Missing seed file: $srcPath');
      exit(2);
    }
    final content = src.readAsStringSync();
    final raw = _render(content, m.constName, m.source.last);
    final desired = _formatInProject(raw, tgtPath, root, dryRun: check);
    final tgt = File(tgtPath);
    final current = tgt.existsSync() ? tgt.readAsStringSync() : '';

    if (current == desired) {
      stdout.writeln('  in sync: ${p.joinAll(m.target)}');
      continue;
    }

    if (check) {
      drifted.add(p.joinAll(m.target));
      continue;
    }

    tgt.createSync(recursive: true);
    tgt.writeAsStringSync(desired);
    stdout.writeln('  wrote:    ${p.joinAll(m.target)}');
  }

  if (drifted.isNotEmpty) {
    stderr.writeln(
      '\nlib/templates is out of sync with templates/:\n'
      '  ${drifted.join('\n  ')}\n'
      'Re-run: dart run tool/sync_templates.dart',
    );
    exit(1);
  }
}

String _render(String content, String constName, String sourceFile) {
  if (content.contains("'''")) {
    throw StateError(
      'Seed file $sourceFile contains a triple-apostrophe; cannot embed '
      "as a Dart r''' raw string. Pick a different quoting strategy.",
    );
  }
  // `// dart format off` keeps `dart format` from rewrapping the
  // single-line `const X = r'''…'''` declaration. We need to opt out
  // because format would otherwise wrap long content onto two lines and
  // un-wrap short content back onto one, leaving --check drifting against
  // the file the generator wrote.
  return '''// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/$sourceFile`.

// dart format off
const String $constName = r\'\'\'$content\'\'\';
''';
}

/// Pipe [source] through `dart format` from within the project, so the
/// generator's output matches what `dart format` would produce on the
/// same file under the project's `pubspec.yaml` SDK constraint. (Format's
/// wrapping behavior is conditional on the package's language version,
/// so formatting in a temp dir produces a different result than
/// formatting in-tree.)
///
/// In dry-run (`--check`) mode the in-place format would mutate the
/// existing file, which would mask drift. Instead we write to a sibling
/// `.tmp` path in the project, format that, read it back, then delete.
String _formatInProject(
  String source,
  String tgtPath,
  String root, {
  required bool dryRun,
}) {
  final tmp = File('$tgtPath.fmt.tmp');
  tmp.createSync(recursive: true);
  tmp.writeAsStringSync(source);
  try {
    final fmt = Process.runSync(
      'dart',
      ['format', '--output=write', tmp.path],
      workingDirectory: root,
    );
    if (fmt.exitCode != 0) {
      stderr.writeln('dart format failed:\n${fmt.stderr}');
      exit(2);
    }
    return tmp.readAsStringSync();
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not find pubspec.yaml walking up from '
        '${Directory.current.path}',
      );
    }
    dir = parent;
  }
}
