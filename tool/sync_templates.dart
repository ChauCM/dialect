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
///   templates/import_plan.md     → lib/templates/import_plan_md.dart
///                                  (const importPlanMdTemplate)
///   templates/describe_plan.md   → lib/templates/describe_plan_md.dart
///                                  (const describePlanMdTemplate)
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
  _Mapping(
    source: ['templates', 'import_plan.md'],
    target: ['lib', 'templates', 'import_plan_md.dart'],
    constName: 'importPlanMdTemplate',
  ),
  _Mapping(
    source: ['templates', 'describe_plan.md'],
    target: ['lib', 'templates', 'describe_plan_md.dart'],
    constName: 'describePlanMdTemplate',
  ),
  _Mapping(
    source: ['templates', 'translate_plan.md'],
    target: ['lib', 'templates', 'translate_plan_md.dart'],
    constName: 'translatePlanMdTemplate',
  ),
  _Mapping(
    source: ['templates', 'init_plan.md'],
    target: ['lib', 'templates', 'init_plan_md.dart'],
    constName: 'initPlanMdTemplate',
  ),
  _Mapping(
    source: ['templates', 'agents_md_section.md'],
    target: ['lib', 'templates', 'agents_md_section.dart'],
    constName: 'agentsMdSection',
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
    final desired = _render(content, m.constName, m.source.last);
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
  // single-line `const X = r'''…'''` declaration. The directive landed
  // in Dart 3.7 and our pubspec sdk constraint pins ^3.11.0, so we can
  // rely on it across every supported SDK.
  return '''// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/$sourceFile`.

// dart format off
const String $constName = r\'\'\'$content\'\'\';
// dart format on
''';
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
