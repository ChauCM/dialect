/// Build the dashboard SPA and bake its `dist/` output into
/// `lib/server/embedded_assets.g.dart` so the Dart binary can serve it
/// with zero `node_modules` on disk at runtime.
///
/// Usage:
///   `dart run tool/build_dashboard.dart`           # full build
///   `dart run tool/build_dashboard.dart --no-pnpm` # skip pnpm,
///                                                  # use existing dist/
///   `dart run tool/build_dashboard.dart --check`   # exit non-zero if
///                                                  # the on-disk asset
///                                                  # file is out of
///                                                  # date with dist/
///
/// Workflow:
///   1. Run `pnpm install` and `pnpm build` under `dashboard/` (unless
///      `--no-pnpm` is passed).
///   2. Walk `dashboard/dist/` recursively.
///   3. Emit a Dart file with a `const Map` named `embeddedAssets`
///      mapping forward-slash paths (relative to `dist/`) to byte
///      arrays.
///
/// CI (M11) runs the no-pnpm variant after caching the dist/ output,
/// then runs `dart compile exe` against the regenerated source.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> arguments) {
  final check = arguments.contains('--check');
  final skipPnpm = arguments.contains('--no-pnpm');
  final root = _repoRoot();

  if (!skipPnpm) {
    _runPnpm(p.join(root, 'dashboard'));
  }

  final dist = Directory(p.join(root, 'dashboard', 'dist'));
  if (!dist.existsSync()) {
    stderr.writeln(
      'No dashboard/dist/ found. Run `cd dashboard && pnpm build`, '
      'or invoke this tool without --no-pnpm to do it automatically.',
    );
    exit(2);
  }

  final assets = <String, List<int>>{};
  for (final entity in dist.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p
        .relative(entity.path, from: dist.path)
        .replaceAll(r'\', '/'); // Windows safety
    assets[rel] = entity.readAsBytesSync();
  }
  if (assets.isEmpty) {
    stderr.writeln('dashboard/dist/ is empty — nothing to bake.');
    exit(2);
  }

  final generated = _render(assets);
  final out = File(p.join(root, 'lib', 'server', 'embedded_assets.g.dart'));
  final current = out.existsSync() ? out.readAsStringSync() : '';

  if (current == generated) {
    stdout.writeln(
      '  in sync: lib/server/embedded_assets.g.dart (${assets.length} files)',
    );
    return;
  }

  if (check) {
    stderr.writeln(
      'lib/server/embedded_assets.g.dart is out of sync with '
      'dashboard/dist/.\nRe-run: dart run tool/build_dashboard.dart',
    );
    exit(1);
  }

  out.writeAsStringSync(generated);
  stdout.writeln(
    '  wrote:   lib/server/embedded_assets.g.dart (${assets.length} files)',
  );
}

void _runPnpm(String dashboardDir) {
  stdout.writeln('  pnpm:    install + build under dashboard/');
  // Install dependencies if node_modules is missing — fresh clones
  // don't have them. Use --frozen-lockfile so CI fails on lockfile
  // drift rather than silently updating.
  final nm = Directory(p.join(dashboardDir, 'node_modules'));
  if (!nm.existsSync()) {
    final r = Process.runSync('pnpm', const [
      'install',
      '--frozen-lockfile',
    ], workingDirectory: dashboardDir);
    if (r.exitCode != 0) {
      stderr.writeln('pnpm install failed:\n${r.stderr}');
      exit(r.exitCode);
    }
  }
  final r = Process.runSync('pnpm', const [
    'build',
  ], workingDirectory: dashboardDir);
  if (r.exitCode != 0) {
    stderr.writeln('pnpm build failed:\n${r.stderr}');
    exit(r.exitCode);
  }
}

String _render(Map<String, List<int>> assets) {
  final keys = assets.keys.toList()..sort();
  final buf = StringBuffer();
  buf.writeln('// GENERATED FILE — do not edit by hand.');
  buf.writeln('// Run `dart run tool/build_dashboard.dart` to regenerate.');
  buf.writeln('// Source of truth: `dashboard/dist/` after `pnpm build`.');
  buf.writeln();
  buf.writeln('// dart format off');
  buf.writeln(
    'const Map<String, List<int>> embeddedAssets = <String, List<int>>{',
  );
  for (final key in keys) {
    final bytes = assets[key]!;
    buf.write('  ');
    buf.write(_jsonEscape(key));
    buf.write(': <int>[');
    for (var i = 0; i < bytes.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(bytes[i]);
    }
    buf.writeln('],');
  }
  buf.writeln('};');
  buf.writeln('// dart format on');
  return buf.toString();
}

String _jsonEscape(String s) {
  final out = StringBuffer('"');
  for (final c in s.codeUnits) {
    if (c == 0x22) {
      out.write(r'\"');
    } else if (c == 0x5C) {
      out.write(r'\\');
    } else if (c < 0x20) {
      out.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
    } else {
      out.writeCharCode(c);
    }
  }
  out.write('"');
  return out.toString();
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
