import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../adapters/arb_adapter.dart';
import '../adapters/json_adapter.dart';
import '../arb/arb_file.dart';
import '../config/dialect_config.dart';
import '../project/dialect_project.dart';

class SyncCommand extends Command<int> {
  SyncCommand() {
    argParser.addFlag(
      'force',
      negatable: false,
      help:
          'Rewrite every output file even if its contents already match. '
          'Use when an external process has touched lib/l10n/ or you want '
          'to refresh mtimes for a downstream watcher.',
    );
  }

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
    final force = results['force'] as bool;
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
    final unnamespacedPerPlatform = <String, Set<String>>{};
    final excludedPerPlatform = <String, Set<String>>{};

    for (final platform in project.config.platforms.values) {
      final _PlatformOutcome outcome;
      try {
        if (platform.format == 'arb') {
          outcome = _syncArbPlatform(project, platform, force: force);
        } else if (JsonAdapter.handles(platform.format)) {
          outcome = _syncJsonPlatform(project, platform, force: force);
        } else {
          stdout.writeln(
            '! ${platform.name} (format: ${platform.format}) — unknown '
            'format; expected one of arb, icu-json, flat-json. Skipping.',
          );
          totalSkipped++;
          continue;
        }
      } on FormatException catch (e) {
        stderr.writeln('✗ ${platform.name}: ${e.message}');
        return 65;
      }
      totalWritten += outcome.filesWritten;
      if (outcome.unnamespacedKeys.isNotEmpty) {
        unnamespacedPerPlatform[platform.name] = outcome.unnamespacedKeys;
      }
      if (outcome.excludedNamespaces.isNotEmpty) {
        excludedPerPlatform[platform.name] = outcome.excludedNamespaces;
      }
      if (outcome.pluralStrippedKeys.isNotEmpty) {
        _warnPluralStripped(platform, outcome.pluralStrippedKeys);
      }
    }

    _maybeWarnUnnamespaced(unnamespacedPerPlatform);
    _maybeWarnExcludedNamespaces(excludedPerPlatform);

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

  /// Sync one `arb`-format platform. Returns ([_PlatformOutcome.filesWritten]
  /// + [_PlatformOutcome.unnamespacedKeys]) — files whose on-disk bytes
  /// already match are touched not at all, preserving mtime.
  _PlatformOutcome _syncArbPlatform(
    DialectProject project,
    PlatformConfig platform, {
    required bool force,
  }) {
    final outDir = Directory(p.join(project.root, platform.output));
    outDir.createSync(recursive: true);

    var written = 0;
    final unnamespacedKeys = <String>{};
    final excludedNamespaces = <String>{};

    // Source ARB — keep metadata.
    final preparedSource = ArbAdapter.prepare(
      project.source,
      platform: platform,
      isSource: true,
    );
    unnamespacedKeys.addAll(preparedSource.keysMissingNamespace);
    excludedNamespaces.addAll(preparedSource.keysExcludedByNamespace.keys);
    if (_maybeWrite(
      outDir.path,
      ArbAdapter.filenameFor(project.config.sourceLocale),
      ArbAdapter.encode(preparedSource.arb),
      force: force,
    )) {
      written++;
    }

    // Translations — strip metadata. Namespace comes from the source ARB
    // (translations carry no `@key` blocks by convention).
    for (final entry in project.translations.entries) {
      final locale = entry.key;
      final prepared = ArbAdapter.prepare(
        entry.value,
        platform: platform,
        isSource: false,
        source: project.source,
      );
      unnamespacedKeys.addAll(prepared.keysMissingNamespace);
      // Excluded namespaces will mirror the source; re-collecting is a
      // no-op for the set but keeps the contract symmetric.
      excludedNamespaces.addAll(prepared.keysExcludedByNamespace.keys);
      if (_maybeWrite(
        outDir.path,
        ArbAdapter.filenameFor(locale),
        ArbAdapter.encode(prepared.arb),
        force: force,
      )) {
        written++;
      }
    }

    return _PlatformOutcome(
      filesWritten: written,
      unnamespacedKeys: unnamespacedKeys,
      excludedNamespaces: excludedNamespaces,
    );
  }

  /// Sync one `icu-json` / `flat-json` backend platform. Reuses the same
  /// namespace filter + metadata strip as the ARB path ([ArbAdapter.prepare]),
  /// then encodes each locale to a flat `<locale>.json` via [JsonAdapter].
  /// For `flat-json`, collects the keys whose ICU expressions were collapsed
  /// so sync can surface the lossy-event hint.
  _PlatformOutcome _syncJsonPlatform(
    DialectProject project,
    PlatformConfig platform, {
    required bool force,
  }) {
    final outDir = Directory(p.join(project.root, platform.output));
    outDir.createSync(recursive: true);

    final stripPlurals = platform.format == 'flat-json';
    var written = 0;
    final unnamespacedKeys = <String>{};
    final excludedNamespaces = <String>{};
    final pluralStrippedKeys = <String>{};

    void emit(ArbFile arb, String locale, {required bool isSource}) {
      final prepared = ArbAdapter.prepare(
        arb,
        platform: platform,
        isSource: isSource,
        source: isSource ? null : project.source,
      );
      unnamespacedKeys.addAll(prepared.keysMissingNamespace);
      excludedNamespaces.addAll(prepared.keysExcludedByNamespace.keys);

      final result = JsonAdapter.encode(
        prepared.arb,
        stripPlurals: stripPlurals,
      );
      pluralStrippedKeys.addAll(result.collapsedKeys);
      if (_maybeWrite(
        outDir.path,
        JsonAdapter.filenameFor(locale),
        result.content,
        force: force,
      )) {
        written++;
      }
    }

    emit(project.source, project.config.sourceLocale, isSource: true);
    for (final entry in project.translations.entries) {
      emit(entry.value, entry.key, isSource: false);
    }

    return _PlatformOutcome(
      filesWritten: written,
      unnamespacedKeys: unnamespacedKeys,
      excludedNamespaces: excludedNamespaces,
      pluralStrippedKeys: pluralStrippedKeys,
    );
  }

  /// flat-json loss-of-information hint (spec: one info line per affected
  /// platform). Lists the keys whose plural/select expressions were
  /// collapsed to their `other` branch.
  void _warnPluralStripped(PlatformConfig platform, Set<String> keys) {
    final sorted = keys.toList()..sort();
    final preview = sorted.length > 8
        ? '${sorted.take(8).join(", ")}, … (${sorted.length - 8} more)'
        : sorted.join(', ');
    stdout.writeln('');
    stdout.writeln(
      'info: ${platform.output}  flat-json strips plurals for: $preview',
    );
    stdout.writeln(
      '  hint: switch this platform to `format: icu-json` if those keys '
      'need locale-correct plurals.',
    );
  }

  /// Emit one summary warning per platform that filtered keys missing
  /// `@key.namespace` metadata. The convention requires source keys to
  /// declare a namespace; without one, the key gets dropped from any
  /// platform that filters.
  void _maybeWarnUnnamespaced(
    Map<String, Set<String>> unnamespacedPerPlatform,
  ) {
    if (unnamespacedPerPlatform.isEmpty) return;
    stdout.writeln('');
    for (final entry in unnamespacedPerPlatform.entries) {
      final keys = entry.value.toList()..sort();
      final preview = keys.length > 5
          ? '${keys.take(5).join(", ")}, … (${keys.length - 5} more)'
          : keys.join(', ');
      stdout.writeln(
        '⚠ ${entry.key}: skipped ${keys.length} key(s) without '
        '`@key.namespace`: $preview',
      );
    }
    stdout.writeln(
      '  hint: add `"namespace": "<group>"` to each key\'s `@key` block, '
      'or set `namespaces: []` on this platform to disable filtering.',
    );
  }

  /// Emit one summary warning per platform whose `namespaces:` allowlist
  /// excluded keys that *did* have a namespace. The pilot case for this:
  /// `dialect.yaml` ships with `namespaces: [common]`, the developer adds
  /// keys in `home`/`checkout`/`settings` namespaces, and sync silently
  /// drops every non-`common` key. Visible warning > silent truncation.
  void _maybeWarnExcludedNamespaces(
    Map<String, Set<String>> excludedPerPlatform,
  ) {
    if (excludedPerPlatform.isEmpty) return;
    stdout.writeln('');
    for (final entry in excludedPerPlatform.entries) {
      final names = entry.value.toList()..sort();
      stdout.writeln(
        '⚠ ${entry.key}: skipped keys in namespace(s) not listed in '
        '`platforms.${entry.key}.namespaces`: ${names.join(", ")}',
      );
    }
    stdout.writeln(
      '  hint: add these namespaces to '
      '`platforms.<p>.namespaces` in dialect.yaml, or set '
      '`namespaces: []` to include every namespace.',
    );
  }

  /// Write [content] to `<dir>/<filename>` only if the on-disk bytes
  /// differ — unless [force] is true, in which case always write.
  /// Returns true if a write happened. Skipping no-op writes keeps
  /// mtimes stable and is part of the idempotency contract.
  bool _maybeWrite(
    String dir,
    String filename,
    String content, {
    required bool force,
  }) {
    final path = p.join(dir, filename);
    final file = File(path);
    if (!force && file.existsSync() && file.readAsStringSync() == content) {
      return false;
    }
    file.writeAsStringSync(content);
    stdout.writeln('  wrote: $path');
    return true;
  }
}

class _PlatformOutcome {
  _PlatformOutcome({
    required this.filesWritten,
    required this.unnamespacedKeys,
    required this.excludedNamespaces,
    this.pluralStrippedKeys = const {},
  });
  final int filesWritten;
  final Set<String> unnamespacedKeys;
  final Set<String> excludedNamespaces;

  /// flat-json only: keys whose ICU plural/select was collapsed. Empty for
  /// the ARB and icu-json paths.
  final Set<String> pluralStrippedKeys;
}
