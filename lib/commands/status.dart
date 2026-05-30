import 'dart:io';

import 'package:args/command_runner.dart';

import '../arb/freshness.dart';
import '../project/dialect_project.dart';
import '../render/table.dart';

class StatusCommand extends Command<int> {
  @override
  String get name => 'status';

  @override
  String get description => 'Show translation coverage per locale.';

  @override
  String get invocation =>
      'dialect status [path]   # path defaults to the current directory';

  @override
  Future<int> run() async {
    final results = argResults!;
    final rest = results.rest;
    if (rest.length > 1) {
      stderr.writeln('status takes at most one positional argument.');
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

    if (project.config.targetLocales.isEmpty) {
      stdout.writeln(
        '! dialect status: no `target_locales` configured in dialect.yaml.',
      );
      stdout.writeln('  Add a target locale and re-run.');
      return 0;
    }

    final summary = computeStatus(project);
    stdout.writeln(renderTable(_tableRows(summary)));
    return 0;
  }

  static List<List<String>> _tableRows(List<LocaleStatus> rows) {
    return [
      const ['Locale', 'Coverage', 'Stale', 'New', 'Locked'],
      for (final r in rows)
        [
          r.locale,
          _percent(r.coverage),
          r.stale.toString(),
          r.missing.toString(),
          r.locked.toString(),
        ],
    ];
  }

  static String _percent(double v) =>
      v == 1.0 ? '100%' : '${(v * 100).toStringAsFixed(1)}%';
}

/// Per-locale [dialect status] row.
///
/// `coverage` is `(source_keys ∩ translation_keys) / source_keys`. With
/// no source keys, coverage is 1.0 by convention (nothing to translate
/// = nothing missing).
///
/// `stale` is the count of translation entries (locked OR unlocked) whose
/// stored `@key.source_hash` no longer matches the current source value's
/// hash per `dialect/spec/source_hash.md` — i.e. the English source
/// changed since the translation was written. Entries with no stored hash
/// are untracked, not stale.
class LocaleStatus {
  LocaleStatus({
    required this.locale,
    required this.coverage,
    required this.missing,
    required this.stale,
    required this.locked,
  });

  final String locale;
  final double coverage;
  final int missing;
  final int stale;
  final int locked;
}

/// Compute per-locale coverage / stale / missing counts for [project].
/// Pure — does not touch the filesystem; callers pass an already-loaded
/// project.
List<LocaleStatus> computeStatus(DialectProject project) {
  final sourceByKey = {for (final e in project.source.entries) e.key: e};
  final sourceKeys = sourceByKey.keys.toSet();
  final sourceHashes = computeSourceHashes(project.source);

  final rows = <LocaleStatus>[];
  for (final locale in project.config.targetLocales) {
    final arb = project.translations[locale];
    final translationKeys = arb == null
        ? const <String>{}
        : {for (final e in arb.entries) e.key};

    final covered = translationKeys.intersection(sourceKeys).length;
    final missing = sourceKeys.difference(translationKeys).length;
    final coverage = sourceKeys.isEmpty ? 1.0 : covered / sourceKeys.length;

    var locked = 0;
    var stale = 0;
    if (arb != null) {
      for (final entry in arb.entries) {
        if (entry.metadata?.locked ?? false) locked++;
        if (isStaleEntry(entry, sourceHashes)) stale++;
      }
    }

    rows.add(
      LocaleStatus(
        locale: locale,
        coverage: coverage,
        missing: missing,
        stale: stale,
        locked: locked,
      ),
    );
  }
  return rows;
}
