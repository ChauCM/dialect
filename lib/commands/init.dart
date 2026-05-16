import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../templates/dialect_yaml.dart';
import '../templates/gitignore_snippet.dart';
import '../templates/glossary_yaml.dart';
import '../templates/source_arb.dart';

class InitCommand extends Command<int> {
  InitCommand() {
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Overwrite an existing dialect/ directory.',
    );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Scaffold the dialect/ directory in the current project.';

  @override
  String get invocation =>
      'dialect init [path]   # path defaults to the current directory';

  @override
  Future<int> run() async {
    final results = argResults!;
    final force = results.flag('force');
    final rest = results.rest;

    if (rest.length > 1) {
      stderr.writeln('init takes at most one positional argument.');
      stderr.writeln(usage);
      return 64; // EX_USAGE
    }

    final targetDir = rest.isEmpty ? Directory.current : Directory(rest.first);
    if (!targetDir.existsSync()) {
      stderr.writeln('Target directory does not exist: ${targetDir.path}');
      return 66; // EX_NOINPUT
    }

    final dialectDir = Directory(p.join(targetDir.path, 'dialect'));
    if (dialectDir.existsSync() && !force) {
      stderr.writeln(
        'dialect/ already exists in ${targetDir.path}.\n'
        'Use --force to overwrite, or delete it first.',
      );
      return 65; // EX_DATAERR
    }

    Directory(p.join(dialectDir.path, 'source')).createSync(recursive: true);
    Directory(
      p.join(dialectDir.path, 'translations'),
    ).createSync(recursive: true);

    File(
      p.join(dialectDir.path, 'dialect.yaml'),
    ).writeAsStringSync(dialectYamlTemplate);
    File(
      p.join(dialectDir.path, 'glossary.yaml'),
    ).writeAsStringSync(glossaryYamlTemplate);
    File(
      p.join(dialectDir.path, 'source', 'en.arb'),
    ).writeAsStringSync(sourceArbTemplate);

    final gitignoreUpdated = _ensureGitignore(targetDir);

    stdout.writeln('✓ Scaffolded dialect/ in ${targetDir.path}');
    stdout.writeln('  dialect/dialect.yaml');
    stdout.writeln('  dialect/glossary.yaml');
    stdout.writeln('  dialect/source/en.arb');
    stdout.writeln('  dialect/translations/  (empty)');
    if (gitignoreUpdated) {
      stdout.writeln('  .gitignore (added .dialect/)');
    }
    stdout.writeln('');
    stdout.writeln('Next steps:');
    stdout.writeln(
      '  1. Edit dialect/dialect.yaml — set your target locales and platforms.',
    );
    stdout.writeln(
      '  2. Edit dialect/glossary.yaml — add any project-specific terms.',
    );
    stdout.writeln(
      '  3. Run `dialect import --from arb --path <existing-arb-path>` to '
      'migrate existing translations,',
    );
    stdout.writeln(
      '     or start adding strings to dialect/source/en.arb directly.',
    );

    return 0;
  }

  /// Add the gitignore snippet to the project's `.gitignore`. Returns
  /// `true` if the file was created or modified, `false` if `.dialect/`
  /// was already present and nothing needed to change.
  bool _ensureGitignore(Directory targetDir) {
    final file = File(p.join(targetDir.path, '.gitignore'));
    if (!file.existsSync()) {
      file.writeAsStringSync(gitignoreSnippet);
      return true;
    }

    final existing = file.readAsStringSync();
    // Crude but safe: a line that's exactly `.dialect/` or `.dialect`.
    final alreadyIgnored = existing
        .split('\n')
        .map((l) => l.trim())
        .any((l) => l == '.dialect/' || l == '.dialect');
    if (alreadyIgnored) return false;

    final separator = existing.endsWith('\n') ? '\n' : '\n\n';
    file.writeAsStringSync('$existing$separator$gitignoreSnippet', flush: true);
    return true;
  }
}
