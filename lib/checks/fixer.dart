import 'dart:io';

import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
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
  /// - in translation ARBs, strips `@key` metadata blocks (the writer
  ///   only emits them when the source ARB shape is detected by a
  ///   non-`@@locale` key matching the convention; translation files
  ///   passed through `_stripMetadata` lose theirs).
  ///
  /// Files that are already canonical are not touched. Returns a
  /// [FixReport] for terminal display.
  static FixReport fix(DialectProject project) {
    final changed = <String>[];

    _maybeRewrite(project.source, changed);
    for (final t in project.translations.values) {
      _maybeRewrite(_stripMetadata(t), changed);
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

  /// Translation ARBs by convention contain only key/value pairs (no
  /// `@key` blocks). If a translation accidentally accumulated metadata
  /// (e.g. a copy-paste from the source), strip it before re-emitting.
  /// Orphan metadata is dropped here too.
  static ArbFile _stripMetadata(ArbFile arb) {
    return ArbFile(
      locale: arb.locale,
      entries: [
        for (final e in arb.entries) ArbEntry(key: e.key, value: e.value),
      ],
      fileMetadata: arb.fileMetadata,
      orphanMetadata: const {},
      entryLines: arb.entryLines,
      sourcePath: arb.sourcePath,
    );
  }
}
