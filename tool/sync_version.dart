/// Keep `lib/version.dart` in sync with `pubspec.yaml`'s `version:` field.
///
/// `pubspec.yaml` is the single source of truth. This tool generates a
/// matching `dialectVersion` constant in `lib/version.dart` so the CLI
/// binary can print its version without reading pubspec at runtime (which
/// is unreliable inside an AOT-compiled `dart compile exe` binary).
///
/// Usage:
///   `dart run tool/sync_version.dart`         # rewrite lib/version.dart
///   `dart run tool/sync_version.dart --check`  # exit non-zero if drift
///
/// CI runs `--check` so a forgotten sync fails the build instead of
/// shipping a binary whose `--version` lies.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;

const _generatedFile = ['lib', 'version.dart'];
const _pubspecFile = ['pubspec.yaml'];

void main(List<String> arguments) {
  final check = arguments.contains('--check');

  final root = _repoRoot();
  final pubspec = File(p.joinAll([root, ..._pubspecFile])).readAsStringSync();
  final pubspecYaml = yaml.loadYaml(pubspec) as yaml.YamlMap;
  final version = pubspecYaml['version'];
  if (version is! String || version.isEmpty) {
    stderr.writeln('pubspec.yaml is missing a `version:` field.');
    exit(2);
  }

  final desired = _renderVersionFile(version);
  final targetPath = p.joinAll([root, ..._generatedFile]);
  final targetFile = File(targetPath);
  final current = targetFile.existsSync() ? targetFile.readAsStringSync() : '';

  if (current == desired) {
    stdout.writeln('lib/version.dart is in sync with pubspec.yaml ($version).');
    return;
  }

  if (check) {
    stderr.writeln(
      'lib/version.dart is out of sync with pubspec.yaml.\n'
      'pubspec.yaml says: $version\n'
      'Re-run: dart run tool/sync_version.dart',
    );
    exit(1);
  }

  targetFile.writeAsStringSync(desired);
  stdout.writeln('Wrote lib/version.dart (version: $version).');
}

String _renderVersionFile(String version) {
  return '''// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_version.dart` to regenerate.
// Source of truth: `pubspec.yaml` `version:` field.

/// The Dialect CLI version.
const String dialectVersion = '$version';
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
