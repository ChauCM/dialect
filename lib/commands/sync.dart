import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../adapters/arb_adapter.dart';
import '../config/dialect_config.dart';
import '../project/dialect_project.dart';

class SyncCommand extends Command<int> {
  @override
  String get name => 'sync';

  @override
  String get description =>
      'Generate platform-specific files from canonical ARB sources.';

  @override
  String get invocation =>
      'dialect sync [path]   # path defaults to the current directory';

  @override
  Future<int> run() async {
    final results = argResults!;
    final rest = results.rest;
    if (rest.length > 1) {
      stderr.writeln('sync takes at most one positional argument.');
      return 64;
    }
    final root = rest.isEmpty ? Directory.current.path : rest.first;

    final DialectProject project;
    try {
      project = DialectProject.load(root);
    } on FileSystemException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(
        'Run `dialect init` first, or pass the project root as an argument.',
      );
      return 66;
    } on FormatException catch (e) {
      stderr.writeln('dialect.yaml or an ARB file is malformed:');
      stderr.writeln('  ${e.message}');
      return 65;
    }

    if (project.config.platforms.isEmpty) {
      stdout.writeln(
        '! dialect sync: no `platforms:` configured in dialect.yaml.',
      );
      stdout.writeln(
        '  Add a platform block (e.g. flutter:) to start emitting files.',
      );
      return 0;
    }

    var totalWritten = 0;
    var totalSkipped = 0;

    for (final platform in project.config.platforms.values) {
      if (platform.format != 'arb') {
        // v1.0 ships only the ARB adapter. Other formats land in v1.1.
        stdout.writeln(
          '! ${platform.name} (format: ${platform.format}) — adapter '
          'lands in v1.1; skipping.',
        );
        totalSkipped++;
        continue;
      }
      final written = _syncPlatform(project, platform);
      totalWritten += written;
    }

    if (totalWritten == 0 && totalSkipped == 0) {
      stdout.writeln(
        '✓ dialect sync: nothing to do (every output is already up to date).',
      );
    } else if (totalWritten == 0) {
      stdout.writeln(
        '✓ dialect sync: $totalSkipped platform(s) skipped, no ARB output.',
      );
    } else {
      stdout.writeln('✓ dialect sync: wrote $totalWritten file(s).');
    }
    return 0;
  }

  /// Sync one platform. Returns the number of files written (or
  /// rewritten — files whose on-disk bytes already match are touched
  /// not at all, preserving mtime).
  int _syncPlatform(DialectProject project, PlatformConfig platform) {
    final outDir = Directory(p.join(project.root, platform.output));
    outDir.createSync(recursive: true);

    var written = 0;

    // Source ARB — keep metadata.
    final sourceOut = _maybeWrite(
      outDir.path,
      ArbAdapter.filenameFor(project.config.sourceLocale),
      ArbAdapter.encode(
        ArbAdapter.prepare(project.source, platform: platform, isSource: true),
      ),
    );
    if (sourceOut) written++;

    // Translations — strip metadata.
    for (final entry in project.translations.entries) {
      final locale = entry.key;
      final translated = ArbAdapter.prepare(
        entry.value,
        platform: platform,
        isSource: false,
      );
      if (_maybeWrite(
        outDir.path,
        ArbAdapter.filenameFor(locale),
        ArbAdapter.encode(translated),
      )) {
        written++;
      }
    }

    return written;
  }

  /// Write [content] to `<dir>/<filename>` only if the on-disk bytes
  /// differ. Returns true if a write happened. Skipping no-op writes
  /// keeps mtimes stable and is part of the idempotency contract.
  bool _maybeWrite(String dir, String filename, String content) {
    final path = p.join(dir, filename);
    final file = File(path);
    if (file.existsSync() && file.readAsStringSync() == content) {
      return false;
    }
    file.writeAsStringSync(content);
    stdout.writeln('  wrote: $path');
    return true;
  }
}
