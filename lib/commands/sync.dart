import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../adapters/arb_adapter.dart';
import '../adapters/json_adapter.dart';
import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../checks/ack.dart';
import '../checks/check_runner.dart';
import '../checks/rule.dart';
import '../config/dialect_config.dart';
import '../project/dialect_project.dart';
import '../project/output_scan.dart';
import '../state/state_store.dart';
import 'key_selection.dart';

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
            'absent from the source) and regenerate without them. An orphan '
            'that also lives in dialect/translations/<locale>.arb is deleted '
            'from there too — otherwise the next sync regenerates it and the '
            'orphan never clears. Opt-in on purpose: pruning throws those '
            'strings away. Pair it with --dry-run to read the exact list '
            'first; nothing is written then.',
      )
      ..addFlag(
        'verify',
        negatable: false,
        help:
            'Exit non-zero if the project still has check errors after '
            'syncing. Sync always reports the post-sync state in one line; '
            'this makes CI fail on it, so `dialect sync --verify` is the '
            'whole gate.',
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
    final verify = results['verify'] as bool;
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
    var scan = OutputScan.run(project, platforms: platforms);

    if (adopt && !dryRun && scan.adoptable.isNotEmpty) {
      // Read the metadata split BEFORE adopting: once the keys are in the
      // source, they are no longer orphans and the scan forgets them.
      final incomplete = scan.keysNeedingMetadata.toList()..sort();
      final adopted = _adoptOrphans(project, scan);
      _reportAdoption(adopted, incomplete);
      // Re-load so generation sees the newly-adopted source keys, then
      // re-scan (adopted keys are no longer orphans).
      project = DialectProject.load(root);
      scan = OutputScan.run(project, platforms: platforms);
    }

    if (scan.isNotEmpty && !prune) {
      _printOrphanRefusal(project, scan, dryRun: dryRun, adoptTried: adopt);
      return dryRun ? 1 : 65;
    }

    // Pruning happens BEFORE generation, not after it. An orphan that is
    // still in dialect/translations/<locale>.arb is regenerated straight back
    // into the output, so a prune that ran afterwards reported a deletion it
    // had not performed and the next `check` reported the same drift forever.
    var pruneRemovals = const <String, Map<String, String>>{};
    if (prune && scan.isNotEmpty) {
      pruneRemovals = _translationBackedOrphans(project, scan);
      _reportPrune(project, scan, pruneRemovals, dryRun: dryRun);
      if (!dryRun && pruneRemovals.isNotEmpty) {
        _pruneTranslations(project, pruneRemovals);
        // Re-load so generation reads the translations as they are now.
        project = DialectProject.load(root);
      }
    }

    var totalWritten = 0;
    var totalSkipped = 0;
    final unnamespacedPerPlatform = <String, Set<String>>{};

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
      if (outcome.pluralStrippedKeys.isNotEmpty) {
        _warnPluralStripped(platform, outcome.pluralStrippedKeys);
      }
    }

    _maybeWarnUnnamespaced(unnamespacedPerPlatform);
    _maybeWarnUnroutedNamespaces(project);

    if (dryRun) {
      // A pending translation deletion is work even when every output file
      // happens to match on disk — under --dry-run the orphan is still in
      // the translations, so generation reproduces the bytes already there.
      // Reporting "up to date" then would be the same lie in a new place.
      final pendingRemovals = pruneRemovals.values.fold<int>(
        0,
        (a, m) => a + m.length,
      );
      if (totalWritten == 0 && pendingRemovals == 0) {
        stdout.writeln('✓ dialect sync --dry-run: every output is up to date.');
        return 0;
      }
      final parts = <String>[
        if (totalWritten > 0) '$totalWritten file(s) would change',
        if (pendingRemovals > 0)
          '$pendingRemovals translation entr'
              '${pendingRemovals == 1 ? 'y' : 'ies'} would be deleted',
      ];
      stdout.writeln(
        '✗ dialect sync --dry-run: ${parts.join(', ')}. '
        'Run `dialect sync${prune ? ' --prune' : ''}` to apply.',
      );
      return 1;
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

    return _reportPostState(root, verify: verify);
  }

  /// Say where the project stands now that the outputs have been written.
  ///
  /// `check → sync → check` was the documented ritual, and the trailing
  /// `check` was three keystrokes asking a question sync already knows the
  /// answer to. Sync reports it unconditionally, because a run that ends
  /// "and it is clean" is worth more than a run that ends silently, and
  /// `--verify` turns that report into the exit code so CI needs one command
  /// rather than two.
  ///
  /// The project is re-loaded rather than reused: sync may have adopted
  /// orphans into the source, and the answer has to describe the files as
  /// they are on disk now. Acknowledgements apply here exactly as they do in
  /// `dialect check`, so an acked warning does not reappear at the end of
  /// every sync.
  int _reportPostState(String root, {required bool verify}) {
    final CheckResult result;
    try {
      final reloaded = DialectProject.load(root);
      result = applyAcks(
        runChecks(reloaded),
        reloaded,
        StateStore.load(root),
      ).result;
    } on FileSystemException catch (e) {
      // The outputs are already written; a failure to re-read the project
      // is worth saying out loud but is not a reason to call the sync bad.
      stdout.writeln('  check: could not re-read the project (${e.message}).');
      return 0;
    } on FormatException catch (e) {
      stdout.writeln('  check: could not re-read the project (${e.message}).');
      return 0;
    }

    final errors = result.issues
        .where((i) => i.severity == IssueSeverity.error)
        .length;
    final warnings = result.issues.length - errors;

    if (errors == 0 && warnings == 0) {
      stdout.writeln('  check: no issues.');
      return 0;
    }
    stdout.writeln(
      '  check: $errors error(s), $warnings warning(s) — run `dialect check` '
      'for detail.',
    );
    return verify && errors > 0 ? 65 : 0;
  }

  /// Report what `--adopt` recovered, and — the part that decides whether the
  /// operator has work left — which of those keys came back without
  /// `namespace`/`description`.
  ///
  /// The hint used to be unconditional, so a run where all 16 keys came back
  /// complete still ended in a paragraph about adding metadata and re-running
  /// sync: the only way to learn there was nothing to do was to open the
  /// source and read 16 `@key` blocks by hand. Inverted, one genuinely bare
  /// key could hide inside a list of twenty complete ones. Naming the
  /// incomplete keys makes the warning a work list and makes silence mean
  /// something.
  void _reportAdoption(Set<String> adopted, List<String> incomplete) {
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
      'translations fresh.',
    );
    if (incomplete.isEmpty) {
      // Nothing further is needed, and this same run regenerates every
      // output — so don't send the caller off to re-run sync.
      stdout.writeln(
        '  All ${describeKeyCount(adopted.length)} came back with '
        '`namespace` + `description`; '
        'the outputs are regenerated below and nothing further is needed.',
      );
    } else {
      stdout.writeln(
        '  ⚠ ${incomplete.length} of ${describeKeyCount(adopted.length)} '
        'still ${incomplete.length == 1 ? 'needs' : 'need'} '
        '`namespace`/`description`:',
      );
      for (final k in incomplete) {
        stdout.writeln('      $k');
      }
      stdout.writeln(
        '    UNTIL A KEY HAS A NAMESPACE it is excluded from every platform '
        'that filters — including the output it was just recovered from. Add '
        'the metadata, then re-run `dialect sync`.',
      );
    }
    stdout.writeln('');
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

    // Source ARB — keep metadata.
    final preparedSource = ArbAdapter.prepare(
      project.source,
      platform: platform,
      isSource: true,
    );
    unnamespacedKeys.addAll(preparedSource.keysMissingNamespace);
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
    final pluralStrippedKeys = <String>{};

    void emit(ArbFile arb, String locale, {required bool isSource}) {
      final prepared = ArbAdapter.prepare(
        arb,
        platform: platform,
        isSource: isSource,
        source: isSource ? null : project.source,
      );
      unnamespacedKeys.addAll(prepared.keysMissingNamespace);

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

  /// Warn about namespaces that reach **no** platform — keys that exist in the
  /// source and are emitted nowhere.
  ///
  /// The pilot case: `dialect.yaml` ships with `namespaces: [common]`, the
  /// developer adds keys under `home`/`checkout`, and sync silently drops every
  /// one of them. Visible warning > silent truncation.
  ///
  /// What this deliberately does NOT warn about is a namespace one platform
  /// excludes and another claims. That is the whole point of an allowlist: on a
  /// project with a Flutter app, a backend and a website reading one source, every
  /// platform excludes most namespaces on purpose, and warning per-platform meant
  /// three paragraphs of noise on every successful sync — which trains people to
  /// stop reading the output, including the line that matters.
  ///
  /// Coverage is computed over EVERY configured platform, not just the ones this
  /// run touched, so `dialect sync --platform backend` does not report the app's
  /// namespaces as homeless.
  void _maybeWarnUnroutedNamespaces(DialectProject project) {
    final platforms = project.config.platforms.values;
    if (platforms.isEmpty) return;
    // A platform with no allowlist takes everything, so nothing is unrouted.
    if (platforms.any((p) => p.namespaces.isEmpty)) return;

    final covered = {for (final p in platforms) ...p.namespaces};
    final unrouted = <String, int>{};
    for (final entry in project.source.entries) {
      final ns = entry.namespace;
      if (ns == null || covered.contains(ns)) continue;
      unrouted[ns] = (unrouted[ns] ?? 0) + 1;
    }
    if (unrouted.isEmpty) return;

    final names = unrouted.keys.toList()..sort();
    stdout.writeln('');
    stdout.writeln(
      '⚠ ${names.length} namespace(s) reach no platform, so their keys are '
      'emitted nowhere:',
    );
    for (final name in names) {
      stdout.writeln('    $name  —  ${unrouted[name]} key(s)');
    }
    stdout.writeln(
      '  hint: add each one to a `platforms.<p>.namespaces` list in '
      'dialect.yaml, or set `namespaces: []` on the platform that should take '
      'everything.',
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
  Set<String> _adoptOrphans(DialectProject project, OutputScan scan) {
    final sourceLocale = project.config.sourceLocale;
    final adoptedKeys = scan.adoptable.keys.toSet();

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
          entries: [...project.source.entries, ...scan.adoptable.values],
          fileMetadata: project.source.fileMetadata,
        ),
      ),
    );

    for (final locEntry in scan.translationValues.entries) {
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

  /// Orphan keys that are ALSO carried by `dialect/translations/<locale>.arb`,
  /// as `locale → (key → translated value)`.
  ///
  /// This is the population that made `--prune` a lie. `OutputScan` reads the
  /// generated outputs, so it sees a key that is absent from the source — but
  /// it cannot see *why* the key keeps coming back. If the key is still in a
  /// translation file, regeneration writes it into the output again, and the
  /// only thing `--prune` used to do was print that it had dropped it.
  Map<String, Map<String, String>> _translationBackedOrphans(
    DialectProject project,
    OutputScan scan,
  ) {
    final orphans = scan.keys;
    final out = <String, Map<String, String>>{};
    for (final entry in project.translations.entries) {
      final hits = <String, String>{};
      for (final e in entry.value.entries) {
        if (orphans.contains(e.key)) hits[e.key] = e.value;
      }
      if (hits.isNotEmpty) out[entry.key] = hits;
    }
    return out;
  }

  /// Say exactly what `--prune` is about to do, split by what actually
  /// happens to each key — and print it BEFORE anything is written, so the
  /// strings that are about to be deleted are on screen while they still
  /// exist. `--dry-run --prune` prints this same list and writes nothing.
  ///
  /// Two populations, two different fates, and lumping them together is what
  /// produced the original defect:
  ///
  /// - **output-only** — the key lives only in a generated file, so
  ///   regenerating drops it and no canonical file is touched.
  /// - **translation-backed** — the key is in `dialect/translations/`, so it
  ///   has to be deleted from there or the next sync puts it straight back.
  void _reportPrune(
    DialectProject project,
    OutputScan scan,
    Map<String, Map<String, String>> removals, {
    required bool dryRun,
  }) {
    final all = scan.keys.toList()..sort();
    final backed = {for (final m in removals.values) ...m.keys};
    final outputOnly = all.where((k) => !backed.contains(k)).toList();

    stdout.writeln('');
    stdout.writeln(
      '⚠ dialect sync --prune: ${all.length} orphan key(s) absent from '
      'dialect/source/${project.config.sourceLocale}.arb.',
    );

    if (outputOnly.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln(
        '  ${dryRun ? 'Would be dropped' : 'Dropped'} by regenerating — they '
        'live only in a generated file:',
      );
      for (final k in outputOnly) {
        final files =
            scan
                .filesFor(k)
                .map((f) => p.relative(f, from: project.root))
                .toList()
              ..sort();
        stdout.writeln('    $k  —  ${files.join(', ')}');
      }
    }

    if (removals.isNotEmpty) {
      final locales = removals.keys.toList()..sort();
      stdout.writeln('');
      stdout.writeln(
        '  ${dryRun ? 'WOULD BE DELETED' : 'DELETED'} from the Dialect '
        'translation source — regenerating alone would put these back, so '
        'the entries themselves ${dryRun ? 'would go' : 'are gone'}:',
      );
      for (final locale in locales) {
        stdout.writeln(
          '    ${p.join('dialect', 'translations', '$locale.arb')}',
        );
        final keys = removals[locale]!.keys.toList()..sort();
        for (final k in keys) {
          stdout.writeln('      $k: ${jsonEncode(removals[locale]![k])}');
        }
      }
      stdout.writeln('');
      stdout.writeln(
        '  Recover with `git diff -- dialect/translations` if this was not '
        'what you meant; `dialect sync --adopt` was the other option.',
      );
    }
    stdout.writeln('');
  }

  /// Delete the pruned keys from `dialect/translations/<locale>.arb`.
  ///
  /// Only the named keys go. Everything else — including each surviving
  /// entry's `@key` block (`source_hash`, `locked`) and the file's `@@`
  /// metadata — is written back through [ArbWriter], the same canonical
  /// writer `--adopt` already uses on these files.
  void _pruneTranslations(
    DialectProject project,
    Map<String, Map<String, String>> removals,
  ) {
    for (final entry in removals.entries) {
      final locale = entry.key;
      final arb = project.translations[locale];
      if (arb == null) continue;
      final drop = entry.value.keys.toSet();
      final kept = [
        for (final e in arb.entries)
          if (!drop.contains(e.key)) e,
      ];
      final path = p.join(
        project.root,
        'dialect',
        'translations',
        '$locale.arb',
      );
      File(path).writeAsStringSync(
        ArbWriter.encode(
          ArbFile(
            locale: arb.locale,
            entries: kept,
            fileMetadata: arb.fileMetadata,
          ),
        ),
      );
    }
  }

  /// Print the "won't silently delete your keys" refusal to stderr and leave
  /// the tree untouched.
  void _printOrphanRefusal(
    DialectProject project,
    OutputScan report, {
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
    // Naming the translation file matters as much as naming the output: an
    // orphan that is still in dialect/translations/ is not a stray line in a
    // generated file, it is a live entry that regeneration keeps restoring.
    // Someone who decides NOT to prune has to know where the second copy is.
    final backed = _translationBackedOrphans(project, report);
    for (final k in keys) {
      final files =
          report
              .filesFor(k)
              .map((f) => p.relative(f, from: project.root))
              .toList()
            ..sort();
      stderr.writeln('    $k  —  ${files.join(', ')}');
      final homes =
          backed.entries
              .where((e) => e.value.containsKey(k))
              .map((e) => p.join('dialect', 'translations', '${e.key}.arb'))
              .toList()
            ..sort();
      if (homes.isNotEmpty) {
        stderr.writeln(
          '           also in ${homes.join(', ')} — regenerating puts it back',
        );
      }
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
        'without them (also deleting them from dialect/translations/)',
      );
      // Before the guard existed, `sync` really did delete these keys, so
      // projects that met it rationally adopted "edit the generated file by
      // hand, never run sync" — and that habit is what produces this pile of
      // orphans. Such a project hits this refusal exactly once, with no way to
      // know its own defensive workaround is the cause.
      stderr.writeln('');
      stderr.writeln(
        '  If this project avoided `sync` because it used to delete keys: '
        'that reason is gone (sync refuses now instead), and `--adopt` is the '
        'one-time migration back onto Dialect.',
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
    this.pluralStrippedKeys = const {},
  });
  final int filesWritten;
  final Set<String> unnamespacedKeys;

  /// flat-json only: keys whose ICU plural/select was collapsed. Empty for
  /// the ARB and icu-json paths.
  final Set<String> pluralStrippedKeys;
}
