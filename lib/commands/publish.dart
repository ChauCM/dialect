import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../bundle/bundle_builder.dart';
import '../bundle/local_target.dart';
import '../config/dialect_config.dart';
import '../project/dialect_project.dart';
import '../version.dart';

/// `dialect publish <env>` (v1.2) — build an immutable bundle from the
/// canonical ARBs and upload it to the env's configured target. See
/// `dialect/spec/bundle.md`.
class PublishCommand extends Command<int> {
  PublishCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Build the bundle and show what would upload, without writing.',
    );
  }

  @override
  String get name => 'publish';

  @override
  String get description =>
      'Build a translation bundle and upload it to a configured target.';

  @override
  String get invocation => 'dialect publish <env> [--dry-run] [project-root]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final dryRun = results['dry-run'] as bool;
    final rest = results.rest;
    if (rest.isEmpty) {
      stderr.writeln('Usage: $invocation');
      stderr.writeln(
        'Name an environment from the `publish:` block, e.g. '
        '`dialect publish production`.',
      );
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
      stderr.writeln('dialect.yaml or an ARB file is malformed:');
      stderr.writeln('  ${e.message}');
      return 65;
    }

    final env = project.config.publishEnvs[envName];
    if (env == null) {
      final configured = project.config.publishEnvs.keys.toList()..sort();
      stderr.writeln(
        'No publish environment `$envName` in dialect.yaml.'
        '${configured.isEmpty ? ' Add a `publish:` block.' : ' Configured: ${configured.join(", ")}.'}',
      );
      return 64;
    }

    final bundle = BundleBuilder.build(
      project,
      env,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      generator: 'dialect $dialectVersion',
    );

    stdout.writeln(
      '✓ built bundle ${bundle.version} '
      '(${bundle.format}, ${bundle.locales.length} locale(s), '
      '${bundle.locales.fold<int>(0, (n, l) => n > l.keys ? n : l.keys)} keys)',
    );

    if (dryRun) {
      stdout.writeln('  dry-run — nothing uploaded. Would write under:');
      stdout.writeln('    ${bundle.versionDir}/manifest.json');
      for (final l in bundle.locales) {
        stdout.writeln('    ${bundle.versionDir}/${l.file}');
      }
      stdout.writeln('  and update the channel head manifest.json.');
      return 0;
    }

    switch (env.target) {
      case 'local':
        return _publishLocal(project, env, bundle);
      case 's3':
        stderr.writeln(
          'The `s3` target is not built yet (the bundle format and the '
          '`local` target ship in v1.2; S3/R2 upload is the next slice). '
          'Use `target: local` to write the same bundle to the filesystem, '
          'then sync that directory to your bucket with your existing '
          'tooling (aws s3 sync / rclone).',
        );
        return 70;
      default:
        stderr.writeln('Unknown target `${env.target}` (expected local | s3).');
        return 64;
    }
  }

  int _publishLocal(
    DialectProject project,
    PublishEnvConfig env,
    Bundle bundle,
  ) {
    final baseDir = p.join(project.root, env.path!, env.prefix);
    final result = LocalTarget.write(baseDir, bundle);

    if (result.alreadyPublished && !result.headUpdated) {
      stdout.writeln(
        '✓ bundle ${bundle.version} already published — nothing to upload.',
      );
      return 0;
    }
    if (result.alreadyPublished) {
      stdout.writeln(
        '✓ bundle ${bundle.version} already present; channel head now points '
        'at it.',
      );
      return 0;
    }
    for (final f in result.filesWritten) {
      stdout.writeln('  wrote ${p.join(env.path!, env.prefix, f)}');
    }
    stdout.writeln(
      '  updated ${p.join(env.path!, env.prefix, 'manifest.json')} → '
      '${bundle.version}',
    );
    return 0;
  }
}
