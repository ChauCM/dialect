import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../adapters/arb_adapter.dart';
import '../adapters/json_adapter.dart';
import '../arb/arb_file.dart';
import '../arb/arb_parser.dart';
import '../arb/arb_writer.dart';
import '../config/dialect_config.dart';
import '../project/dialect_project.dart';

class SyncCommand extends Command<int> {
  SyncCommand() {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help:
            'Rewrite every output file even if its contents already match. '
            'Use when an external process has touched lib/l10n/ or you want '
            'to refresh mtimes for a downstream watcher.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help:
            'Show which files would change without writing anything. '
            'Exits non-zero if any file is out of date — useful as a CI '
            'gate that the committed outputs match the source.',
      )
      ..addOption(
        'platform',
        help:
            'Sync only the named platform from dialect.yaml (e.g. '
            '`--platform backend`). Default: every configured platform.',
        valueHelp: 'name',
      )
      ..addFlag(
        'adopt',
        negatable: false,
        help:
            'Recover orphan keys — keys that exist in a generated output but '
            'not in the source (someone edited a generated file by hand). '
            'Pull them back into dialect/source/<locale>.arb, then sync. '
            'Without this (or --prune), sync refuses when it would delete '
            'orphan keys.',
      )
      ..addFlag(
        'prune',
        negatable: false,
        help:
            'Confirm the deletion of orphan keys (present in the output, '
            'absent from the source) and regenerate without them. Opt-in on '
            'purpose: pruning throws away whatever strings live only in the '
            'generated file.',
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
    final dryRun = results['dry-run'] as bool;
    final adopt = results['adopt'] as bool;
    final prune = results['prune'] as bool;
    final onlyPlatform = results.option('platform');
    final rest = results.rest;
    if (rest.length > 1) {
      stderr.writeln('sync takes at most one positional argument.');
      return 64;
    }
    final root = rest.isEmpty ? Directory.current.path : rest.first;

    DialectProject project;
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

    final platforms = project.config.platforms.values.toList();
    if (onlyPlatform != null) {
      final match = platforms.where((p) => p.name == onlyPlatform).toList();
      if (match.isEmpty) {
        stderr.writeln(
          'No platform named `$onlyPlatform` in dialect.yaml. '
          'Configured: ${platforms.map((p) => p.name).join(", ")}.',
        );
        return 64;
      }
      platforms
        ..clear()
        ..addAll(match);
    }

    // Non-destructive guard: never silently delete keys that live in the
    // generated output but not in the source (the out-of-band-edit trap
    // that quietly lost 7 live keys in Dialect's first field use). Scan
    // first; refuse, adopt, or prune — but never drop them by surprise.
    var scan = _scanOrphans(project, platforms);

    if (adopt && !dryRun && scan.adoptable.isNotEmpty) {
      final adopted = _adoptOrphans(project, scan);
      final names = adopted.toList()..sort();
      stdout.writeln(
        '✓ dialect sync --adopt: recovered ${adopted.length} orphan key(s) '
        'into the Dialect source (plus any translations that lived only in '
        'the output):',
      );
      for (final k in names) {
        stdout.writeln('  $k');
      }
      stdout.writeln(
        '  hint: run `dialect check --fix` — it stamps the recovered '
        'translations fresh, and an adopted key still needs a '
        '`namespace`/`description` if its @key block did not carry one.',
      );
      stdout.writeln('');
      // Re-load so generation sees the newly-adopted source keys, then
      // re-scan (adopted keys are no longer orphans).
      project = DialectProject.load(root);
      scan = _scanOrphans(project, platforms);
    }

    if (!scan.isEmpty && !prune) {
      _printOrphanRefusal(project, scan, dryRun: dryRun, adoptTried: adopt);
      return dryRun ? 1 : 65;
    }

    var totalWritten = 0;
    var totalSkipped = 0;
    final unnamespacedPerPlatform = <String, Set<String>>{};
    final excludedPerPlatform = <String, Set<String>>{};

    for (final platform in platforms) {
      final _PlatformOutcome outcome;
      try {
        if (platform.format == 'arb') {
          outcome = _syncArbPlatform(
            project,
            platform,
            force: force,
            dryRun: dryRun,
          );
        } else if (JsonAdapter.handles(platform.format)) {
          outcome = _syncJsonPlatform(
            project,
            platform,
            force: force,
            dryRun: dryRun,
          );
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

    if (dryRun) {
      if (totalWritten == 0) {
        stdout.writeln('✓ dialect sync --dry-run: every output is up to date.');
        return 0;
      }
      stdout.writeln(
        '✗ dialect sync --dry-run: $totalWritten file(s) would change. '
        'Run `dialect sync` to write them.',
      );
      return 1;
    }

    if (prune && !scan.isEmpty) {
      final pruned = scan.keys.toList()..sort();
      stdout.writeln('');
      stdout.writeln(
        '⚠ dialect sync --prune: dropped ${pruned.length} orphan key(s) '
        'absent from the source:',
      );
      for (final k in pruned) {
        stdout.writeln('  $k');
      }
      stdout.writeln('');
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

  /// Sync one `arb`-format platform. Returns ([_PlatformOutcome.filesWritten]
  /// + [_PlatformOutcome.unnamespacedKeys]) — files whose on-disk bytes
  /// already match are touched not at all, preserving mtime.
  _PlatformOutcome _syncArbPlatform(
    DialectProject project,
    PlatformConfig platform, {
    required bool force,
    required bool dryRun,
  }) {
    final outDir = Directory(p.join(project.root, platform.output));
    if (!dryRun) outDir.createSync(recursive: true);

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
      dryRun: dryRun,
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
        dryRun: dryRun,
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
    required bool dryRun,
  }) {
    final outDir = Directory(p.join(project.root, platform.output));
    if (!dryRun) outDir.createSync(recursive: true);

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
        dryRun: dryRun,
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
  /// Returns true if a write happened (or, under [dryRun], *would* have).
  /// Skipping no-op writes keeps mtimes stable and is part of the
  /// idempotency contract. Under [dryRun] nothing is written and the line
  /// reads `would write:` instead of `wrote:`.
  bool _maybeWrite(
    String dir,
    String filename,
    String content, {
    required bool force,
    required bool dryRun,
  }) {
    final path = p.join(dir, filename);
    final file = File(path);
    if (!force && file.existsSync() && file.readAsStringSync() == content) {
      return false;
    }
    if (dryRun) {
      stdout.writeln('  would write: $path');
      return true;
    }
    file.writeAsStringSync(content);
    stdout.writeln('  wrote: $path');
    return true;
  }

  /// Scan the on-disk outputs of [platforms] for **orphan keys**: keys that
  /// appear in a generated output file but not in the canonical source ARB.
  /// These almost always come from editing a generated file by hand — the
  /// trap that silently deleted 7 live keys the first time Dialect ran on a
  /// real project. Regenerating would drop them, so sync refuses unless the
  /// caller opts in with `--adopt` (recover into the source) or `--prune`
  /// (confirm the deletion). JSON outputs are scanned too. The source-locale
  /// output yields the recoverable English value (+ any `@key` metadata); a
  /// translation output yields the translated value, so `--adopt` can put
  /// both back rather than silently dropping the translation on regenerate.
  _OrphanReport _scanOrphans(
    DialectProject project,
    List<PlatformConfig> platforms,
  ) {
    final sourceKeys = {for (final e in project.source.entries) e.key};
    final sourceLocale = project.config.sourceLocale;
    final locales = <String>{sourceLocale, ...project.config.targetLocales};
    final report = _OrphanReport();

    for (final platform in platforms) {
      final isArb = platform.format == 'arb';
      final isJson = JsonAdapter.handles(platform.format);
      // Unknown formats emit nothing (see the run loop), so they can't have
      // orphans we'd delete. Skip them.
      if (!isArb && !isJson) continue;
      final outDir = p.join(project.root, platform.output);

      for (final locale in locales) {
        final filename = isArb
            ? ArbAdapter.filenameFor(locale)
            : JsonAdapter.filenameFor(locale);
        final path = p.join(outDir, filename);
        final file = File(path);
        if (!file.existsSync()) continue;

        final Map<String, ArbEntry> onDisk;
        try {
          onDisk = _readOutputEntries(file.readAsStringSync(), isArb: isArb);
        } on FormatException {
          // A malformed output isn't a data-loss concern — the next write
          // replaces it with canonical bytes. Skip it for scanning.
          continue;
        }

        for (final entry in onDisk.values) {
          if (sourceKeys.contains(entry.key)) continue;
          report._files.putIfAbsent(entry.key, () => <String>{}).add(path);
          if (locale == sourceLocale) {
            // The source-locale output carries the English value (+ any
            // @key metadata) — that's what makes a key recoverable.
            report._sourceEntries.putIfAbsent(entry.key, () => entry);
          } else {
            // A translation output carries a translated value that
            // regenerate would otherwise drop. Recover it with the source.
            report._translationEntries
                .putIfAbsent(locale, () => <String, String>{})
                .putIfAbsent(entry.key, () => entry.value);
          }
        }
      }
    }
    return report;
  }

  /// Parse one output file into `key → ArbEntry`. ARB outputs keep their
  /// `@key` metadata so `--adopt` can carry a description/namespace back into
  /// the source; JSON outputs are flat `key → value`.
  Map<String, ArbEntry> _readOutputEntries(
    String content, {
    required bool isArb,
  }) {
    if (isArb) {
      final arb = ArbParser.parse(content);
      return {for (final e in arb.entries) e.key: e};
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('output JSON is not an object');
    }
    final out = <String, ArbEntry>{};
    decoded.forEach((k, v) {
      if (k is String && v is String) out[k] = ArbEntry(key: k, value: v);
    });
    return out;
  }

  /// Recover the orphans into the Dialect source. Returns the adopted keys.
  ///
  /// - **Source:** each recovered entry (value + any `@key` metadata) is
  ///   taken verbatim from the source-locale output, so a hand-added string
  ///   keeps whatever description/namespace it was given.
  /// - **Translations:** any translated value that lived only in a
  ///   translation output is written back into
  ///   `dialect/translations/<locale>.arb` (bare, metadata-stripped by
  ///   convention) — otherwise the next regenerate would drop it. Only keys
  ///   we just adopted into the source qualify; an orphan with no English
  ///   value can't become a real key. `dialect check --fix` stamps the
  ///   `source_hash` on the finalize pass.
  Set<String> _adoptOrphans(DialectProject project, _OrphanReport report) {
    final sourceLocale = project.config.sourceLocale;
    final adoptedKeys = report._sourceEntries.keys.toSet();

    final sourcePath = p.join(
      project.root,
      'dialect',
      'source',
      '$sourceLocale.arb',
    );
    File(sourcePath).writeAsStringSync(
      ArbWriter.encode(
        ArbFile(
          locale: project.source.locale,
          entries: [...project.source.entries, ...report._sourceEntries.values],
          fileMetadata: project.source.fileMetadata,
        ),
      ),
    );

    for (final locEntry in report._translationEntries.entries) {
      final locale = locEntry.key;
      final existing = project.translations[locale];
      final existingKeys = {
        if (existing != null)
          for (final e in existing.entries) e.key,
      };
      final recovered = <ArbEntry>[
        for (final e in locEntry.value.entries)
          if (adoptedKeys.contains(e.key) && !existingKeys.contains(e.key))
            ArbEntry(key: e.key, value: e.value),
      ];
      if (recovered.isEmpty) continue;

      final tPath = p.join(
        project.root,
        'dialect',
        'translations',
        '$locale.arb',
      );
      File(tPath).parent.createSync(recursive: true);
      File(tPath).writeAsStringSync(
        ArbWriter.encode(
          ArbFile(
            locale: existing?.locale ?? locale,
            entries: [if (existing != null) ...existing.entries, ...recovered],
            fileMetadata: existing?.fileMetadata ?? const {},
          ),
        ),
      );
    }

    return adoptedKeys;
  }

  /// Print the "won't silently delete your keys" refusal to stderr and leave
  /// the tree untouched.
  void _printOrphanRefusal(
    DialectProject project,
    _OrphanReport report, {
    required bool dryRun,
    required bool adoptTried,
  }) {
    final sourceLocale = project.config.sourceLocale;
    final keys = report.keys.toList()..sort();
    stderr.writeln(
      '✗ dialect sync: refusing to run — the generated output holds '
      '${keys.length} key(s) that are not in your source '
      '(dialect/source/$sourceLocale.arb). Regenerating would delete them.',
    );
    stderr.writeln(
      '  They were almost certainly added straight to a generated file, '
      'bypassing Dialect:',
    );
    stderr.writeln('');
    for (final k in keys) {
      final files =
          report._files[k]!
              .map((f) => p.relative(f, from: project.root))
              .toList()
            ..sort();
      stderr.writeln('    $k  —  ${files.join(', ')}');
    }
    stderr.writeln('');
    final unadoptable = report.unadoptableKeys;
    if (!adoptTried || report.adoptable.isNotEmpty) {
      stderr.writeln('  Pick one:');
      stderr.writeln(
        '    dialect sync --adopt   pull them into '
        'dialect/source/$sourceLocale.arb, then sync',
      );
      stderr.writeln(
        '    dialect sync --prune   confirm the deletion and regenerate '
        'without them',
      );
    }
    if (adoptTried && unadoptable.isNotEmpty) {
      stderr.writeln(
        '  ${unadoptable.length} of these live only in a translation output '
        '(no source-locale value to adopt). Add them to the source by hand, '
        'or `dialect sync --prune` to drop them.',
      );
    }
    stderr.writeln('');
    stderr.writeln('  Nothing was written.');
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

/// The result of [SyncCommand._scanOrphans]: orphan keys (present in a
/// generated output, absent from the source) grouped by which output files
/// carry them, plus what `--adopt` would recover for each.
class _OrphanReport {
  /// orphan key → the output file paths it was found in.
  final Map<String, Set<String>> _files = {};

  /// orphan key → the source-locale [ArbEntry] `--adopt` writes into the
  /// source. Absent for keys that live only in a translation output (no
  /// English value to adopt).
  final Map<String, ArbEntry> _sourceEntries = {};

  /// locale → (orphan key → translated value) recovered from translation
  /// outputs, so `--adopt` restores translations instead of dropping them.
  final Map<String, Map<String, String>> _translationEntries = {};

  bool get isEmpty => _files.isEmpty;

  Set<String> get keys => _files.keys.toSet();

  /// Keys `--adopt` can recover into the source, mapped to the entry it
  /// would write.
  Map<String, ArbEntry> get adoptable => _sourceEntries;

  /// Orphans with no source-locale value — `--adopt` can't recover these.
  Set<String> get unadoptableKeys =>
      keys.difference(_sourceEntries.keys.toSet());
}
