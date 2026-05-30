import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../bundle/local_target.dart';
import '../project/dialect_project.dart';

/// `dialect pull [<env>]` (v1.2) — fetch the latest published bundle for an
/// environment and write its per-locale JSON into the env's `output`
/// directory (verifying SHA-256 integrity). For CI deploy scripts. See
/// `dialect/spec/bundle.md`.
class PullCommand extends Command<int> {
  @override
  String get name => 'pull';

  @override
  String get description =>
      'Fetch the latest published bundle into the env output directory.';

  @override
  String get invocation => 'dialect pull <env> [project-root]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final rest = results.rest;
    if (rest.isEmpty) {
      stderr.writeln('Usage: $invocation');
      return 64;
    }
    final envName = rest.first;
    final root = rest.length > 1 ? rest[1] : Directory.current.path;

    final DialectProject project;
    try {
      project = DialectProject.load(root);
    } on FileSystemException catch (e) {
      stderr.writeln(e.message);
      return 66;
    } on FormatException catch (e) {
      stderr.writeln('dialect.yaml is malformed: ${e.message}');
      return 65;
    }

    final env = project.config.publishEnvs[envName];
    if (env == null) {
      stderr.writeln('No publish environment `$envName` in dialect.yaml.');
      return 64;
    }
    if (env.output == null || env.output!.isEmpty) {
      stderr.writeln(
        'publish.$envName.output is required for `dialect pull` — it is the '
        'directory the fetched locale files are written into '
        '(e.g. `api/locales/`).',
      );
      return 64;
    }

    if (env.target != 'local') {
      stderr.writeln(
        'Pulling a `${env.target}` target is not built yet. For now, fetch '
        'the bundle directory with your own tooling, or use `target: local`.',
      );
      return 70;
    }

    final baseDir = p.join(project.root, env.path!, env.prefix);
    final PulledBundle pulled;
    try {
      pulled = LocalTarget.read(baseDir);
    } on FormatException catch (e) {
      stderr.writeln('✗ pull failed: ${e.message}');
      return 65;
    }

    final outDir = Directory(p.join(project.root, env.output!));
    outDir.createSync(recursive: true);
    for (final l in pulled.locales) {
      File(p.join(outDir.path, l.file)).writeAsStringSync(l.content);
    }

    final counts = pulled.locales
        .map((l) => '${l.locale}: ${l.keys ?? '?'}')
        .join(', ');
    stdout.writeln('✓ pulled ${pulled.version} → ${env.output}  ($counts)');
    return 0;
  }
}
