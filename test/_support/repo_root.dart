import 'dart:io';

import 'package:path/path.dart' as p;

/// Absolute path to this package's repo root, derived by walking up from
/// the current working directory until a `pubspec.yaml` is found.
///
/// Lets fixture-loading tests work regardless of which directory the
/// developer (or `dart test`) was invoked from.
String repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not find pubspec.yaml walking up from ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// Resolve [segments] against the repo root.
String repoPath(List<String> segments) => p.joinAll([repoRoot(), ...segments]);
