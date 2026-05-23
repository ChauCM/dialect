/// Render the Homebrew formula for a given release tag by pulling
/// SHA-256 checksums from the published GitHub release's SHA256SUMS
/// asset.
///
/// Usage (from the release workflow):
///   `dart run tool/render_homebrew_formula.dart --version v1.0.0`
///
/// Reads `homebrew/dialect.rb.tmpl`, fetches
/// `https://github.com/ChauCM/dialect/releases/download/v1.0.0/SHA256SUMS`,
/// substitutes `{{VERSION}}` (with the leading `v` stripped) and each
/// per-target SHA-256 placeholder, and writes the rendered formula to
/// stdout.
///
/// Missing checksums abort with a non-zero exit so the bump-PR is
/// never opened with a half-rendered formula.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const String _repo = 'ChauCM/dialect';

const Map<String, String> _archiveByPlaceholder = {
  'MACOS_ARM64_SHA256': 'dialect-macos-arm64.tar.gz',
  'LINUX_X64_SHA256': 'dialect-linux-x64.tar.gz',
};

Future<int> main(List<String> arguments) async {
  String? rawVersion;
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--version' && i + 1 < arguments.length) {
      rawVersion = arguments[i + 1];
      i++;
    }
  }
  if (rawVersion == null || rawVersion.isEmpty) {
    stderr.writeln('usage: render_homebrew_formula.dart --version vX.Y.Z');
    return 64;
  }
  final tag = rawVersion;
  final version = rawVersion.startsWith('v')
      ? rawVersion.substring(1)
      : rawVersion;

  final templatePath = p.join(_repoRoot(), 'homebrew', 'dialect.rb.tmpl');
  final template = File(templatePath).readAsStringSync();

  final sums = await _fetchSha256Sums(tag);
  if (sums.isEmpty) {
    stderr.writeln(
      'No SHA256SUMS entries found for release $tag. Did the build job finish?',
    );
    return 1;
  }

  var rendered = template.replaceAll('{{VERSION}}', version);
  final missing = <String>[];
  for (final entry in _archiveByPlaceholder.entries) {
    final archive = entry.value;
    final hash = sums[archive];
    if (hash == null) {
      missing.add(archive);
      continue;
    }
    rendered = rendered.replaceAll('{{${entry.key}}}', hash);
  }
  if (missing.isNotEmpty) {
    stderr.writeln('SHA256SUMS is missing entries for: ${missing.join(', ')}');
    return 1;
  }
  stdout.write(rendered);
  return 0;
}

Future<Map<String, String>> _fetchSha256Sums(String tag) async {
  final url = Uri.parse(
    'https://github.com/$_repo/releases/download/$tag/SHA256SUMS',
  );
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    req.followRedirects = true;
    req.maxRedirects = 10;
    final res = await req.close();
    if (res.statusCode != 200) {
      throw HttpException('GET $url returned ${res.statusCode}');
    }
    final body = await res.transform(SystemEncoding().decoder).join();
    final out = <String, String>{};
    for (final line in const LineSplitter().convert(body)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Format: "<hex>  <filename>".
      final match = RegExp(r'^([0-9a-fA-F]{64})\s+(.+)$').firstMatch(trimmed);
      if (match == null) continue;
      out[match.group(2)!] = match.group(1)!.toLowerCase();
    }
    return out;
  } finally {
    client.close();
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
