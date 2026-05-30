import 'dart:io';

import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../arb/freshness.dart';
import '../project/dialect_project.dart';

/// Result of `dialect check --fix`: which files were rewritten and the
/// total count, for terminal output.
class FixReport {
  FixReport({required this.changedFiles});

  /// Files that were re-written because their on-disk form differed from
  /// canonical. Paths match `ArbFile.sourcePath`.
  final List<String> changedFiles;

  int get count => changedFiles.length;
}

class Fixer {
  Fixer._();

  /// Walk every ARB in [project] and re-emit it through [ArbWriter]. The
  /// writer's canonical form deterministically:
  ///
  /// - sorts keys byte-wise lexicographic,
  /// - hoists `@@locale` to the top,
  /// - places each `@key` block immediately after its key,
  /// - emits `@@` file-level metadata (preserved verbatim) after
  ///   `@@locale`,
  /// - drops `orphanMetadata` (by construction — writer never emits it),
  /// - in translation ARBs, strips **descriptive** `@key` metadata
  ///   (`namespace`/`description`/`context`/`placeholders` — those live in
  ///   the source), preserves **state** metadata (`locked`, `source_hash`),
  ///   and stamps `source_hash` onto unlocked entries that lack one (see
  ///   [normalizeTranslation]).
  ///
  /// Files that are already canonical are not touched. Returns a
  /// [FixReport] for terminal display.
  static FixReport fix(DialectProject project) {
    final changed = <String>[];
    final sourceHashes = computeSourceHashes(project.source);

    _maybeRewrite(project.source, changed);
    for (final t in project.translations.values) {
      _maybeRewrite(normalizeTranslation(t, sourceHashes), changed);
    }

    return FixReport(changedFiles: changed);
  }

  static void _maybeRewrite(ArbFile arb, List<String> changed) {
    final path = arb.sourcePath;
    if (path == null) return; // unit-test arb without a path
    final emitted = ArbWriter.encode(arb);
    final file = File(path);
    if (!file.existsSync() || file.readAsStringSync() != emitted) {
      file.writeAsStringSync(emitted);
      changed.add(path);
    }
  }
}
