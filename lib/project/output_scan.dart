import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../adapters/arb_adapter.dart';
import '../adapters/json_adapter.dart';
import '../arb/arb_file.dart';
import '../arb/arb_parser.dart';
import '../config/dialect_config.dart';
import 'dialect_project.dart';

/// Compares the generated outputs on disk against the canonical source, and
/// reports **orphan keys**: keys that exist in a generated file but not in
/// `dialect/source`.
///
/// An orphan means someone edited a generated file by hand. Regenerating
/// deletes it, which is the trap that silently lost 7 live keys the first time
/// Dialect ran on a real project — so `sync` refuses on it, and `check`
/// reports it.
///
/// Both commands read the same scan on purpose. `check` used to look only at
/// `dialect/source` + `dialect/translations`, so it stayed green on a repo
/// where `sync` was guaranteed to refuse: the prescribed first command could
/// not answer "is this repo in a state where sync can run?". One scanner, two
/// consumers, one answer.
class OutputScan {
  OutputScan._();

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

  bool get isNotEmpty => _files.isNotEmpty;

  Set<String> get keys => _files.keys.toSet();

  /// Output files carrying [key], as recorded during the scan.
  Set<String> filesFor(String key) => _files[key] ?? const {};

  /// Keys `--adopt` can recover into the source, mapped to the entry it
  /// would write.
  Map<String, ArbEntry> get adoptable => _sourceEntries;

  /// Translated values that live only in a translation output, keyed by
  /// locale. `--adopt` restores these alongside the source entry.
  Map<String, Map<String, String>> get translationValues => _translationEntries;

  /// Orphans with no source-locale value — `--adopt` can't recover these.
  Set<String> get unadoptableKeys =>
      keys.difference(_sourceEntries.keys.toSet());

  /// Orphans that came back from [adoptable] already carrying both a
  /// `namespace` and a `description`, so adopting them needs no follow-up.
  Set<String> get completeKeys => {
    for (final e in _sourceEntries.entries)
      if (_hasNamespace(e.value) && _hasDescription(e.value)) e.key,
  };

  /// Adoptable orphans still missing `namespace` and/or `description`.
  ///
  /// A key with no namespace is excluded from every platform that filters —
  /// including the output it was just recovered from — so this set is the
  /// work list `--adopt` leaves behind, and an empty one means "nothing
  /// further to do".
  Set<String> get keysNeedingMetadata =>
      _sourceEntries.keys.toSet().difference(completeKeys);

  static bool _hasNamespace(ArbEntry e) {
    final ns = e.metadata?.namespace;
    return ns != null && ns.isNotEmpty;
  }

  static bool _hasDescription(ArbEntry e) {
    final d = e.metadata?.description;
    return d != null && d.isNotEmpty;
  }

  /// Scan the on-disk outputs of [platforms] (default: every configured
  /// platform) for orphan keys.
  ///
  /// The source-locale output yields the recoverable English value (+ any
  /// `@key` metadata); a translation output yields the translated value, so
  /// `--adopt` can put both back rather than silently dropping the
  /// translation on regenerate.
  static OutputScan run(
    DialectProject project, {
    List<PlatformConfig>? platforms,
  }) {
    final targets = platforms ?? project.config.platforms.values.toList();
    final sourceKeys = {for (final e in project.source.entries) e.key};
    final sourceLocale = project.config.sourceLocale;
    final locales = <String>{sourceLocale, ...project.config.targetLocales};
    final scan = OutputScan._();

    for (final platform in targets) {
      final isArb = platform.format == 'arb';
      final isJson = JsonAdapter.handles(platform.format);
      // Unknown formats emit nothing, so they can't have orphans we'd
      // delete. Skip them.
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
          scan._files.putIfAbsent(entry.key, () => <String>{}).add(path);
          if (locale == sourceLocale) {
            scan._sourceEntries.putIfAbsent(entry.key, () => entry);
          } else {
            scan._translationEntries
                .putIfAbsent(locale, () => <String, String>{})
                .putIfAbsent(entry.key, () => entry.value);
          }
        }
      }
    }
    return scan;
  }

  /// Parse one output file into `key → ArbEntry`. ARB outputs keep their
  /// `@key` metadata so `--adopt` can carry a description/namespace back into
  /// the source; JSON outputs are flat `key → value`.
  static Map<String, ArbEntry> _readOutputEntries(
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
}
