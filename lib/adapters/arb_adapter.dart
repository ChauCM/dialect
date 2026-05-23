import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../config/dialect_config.dart';

/// ARB-passthrough adapter. The only adapter Dialect ships in v1.0 —
/// every other platform (Apple `.strings`, Android `strings.xml`,
/// `flat-json`, `icu-json`) is parked for v1.1.
///
/// Two transforms happen during sync:
///
/// 1. **Namespace filter.** Only keys whose `@key.namespace` metadata
///    appears in [PlatformConfig.namespaces] are included. An empty
///    namespaces list disables the filter — every key passes. The
///    namespace is always read from the **source** ARB's `@key` block:
///    translation files don't carry `@key` metadata by convention, so
///    looking it up there would drop every translated key. Keys with no
///    source-side namespace flow back through
///    [PreparedArb.keysMissingNamespace] so sync can surface them.
/// 2. **Metadata stripping.** Source ARBs keep their `@key` blocks
///    intact (Flutter's `gen_l10n` reads them). Translation ARBs are
///    key/value-only by convention; if a translation accidentally
///    accumulated `@key` blocks, the adapter strips them.
///
/// Output is always [ArbWriter] canonical form — that's the idempotency
/// contract (`sync` twice = same bytes). `dialect check --fix` reuses
/// the same writer, so a synced ARB run back through `--fix` is a no-op.
///
/// **The adapter does not modify input ARBs.** No "auto-fix" during
/// sync; that's `dialect check --fix`'s job.
class ArbAdapter {
  const ArbAdapter._();

  /// Apply the namespace filter and strip translation metadata, returning
  /// a [PreparedArb] ready to hand to [ArbWriter] (plus diagnostics).
  ///
  /// [isSource] preserves `@key` metadata when true; false strips it.
  /// When [isSource] is false, [source] must be provided so the filter
  /// can look up each key's namespace from the source ARB.
  static PreparedArb prepare(
    ArbFile arb, {
    required PlatformConfig platform,
    required bool isSource,
    ArbFile? source,
  }) {
    assert(
      isSource || source != null,
      'translation ARBs need the source ARB to resolve namespaces',
    );
    final namespaces = platform.namespaces;
    final keepAll = namespaces.isEmpty;
    final ns = namespaces.toSet();

    final namespaceOf = isSource
        ? null
        : {for (final e in source!.entries) e.key: e.namespace};

    final entries = <ArbEntry>[];
    final missingNamespace = <String>[];
    for (final entry in arb.entries) {
      if (!keepAll) {
        final entryNs = isSource ? entry.namespace : namespaceOf![entry.key];
        if (entryNs == null) {
          missingNamespace.add(entry.key);
          continue;
        }
        if (!ns.contains(entryNs)) continue;
      }
      entries.add(
        isSource ? entry : ArbEntry(key: entry.key, value: entry.value),
      );
    }

    return PreparedArb(
      arb: ArbFile(
        locale: arb.locale,
        entries: entries,
        fileMetadata: arb.fileMetadata,
        // Orphans are never emitted — same contract as the writer.
        orphanMetadata: const {},
        // Line numbers are tied to the source file; meaningless after
        // namespace filtering. Drop them.
        entryLines: const {},
        sourcePath: arb.sourcePath,
      ),
      keysMissingNamespace: missingNamespace,
    );
  }

  /// Render an [ArbFile] to canonical bytes via [ArbWriter].
  static String encode(ArbFile arb) => ArbWriter.encode(arb);

  /// Filename convention for v1.0: `app_<locale>.arb`. Matches Flutter's
  /// `gen_l10n` default. **v1.1** will spec a configurable pattern under
  /// `platforms.<p>.filename_pattern`.
  static String filenameFor(String locale) => 'app_$locale.arb';
}

/// Output of [ArbAdapter.prepare]: the filtered ARB plus a list of keys
/// dropped because they had no `@key.namespace` declaration to filter on.
class PreparedArb {
  PreparedArb({required this.arb, required this.keysMissingNamespace});

  /// The filtered, metadata-handled ARB ready for [ArbWriter].
  final ArbFile arb;

  /// Keys dropped from the output because the source ARB didn't declare
  /// `@key.namespace`. Empty when filtering is off or when every source
  /// key has a namespace. The source ARB likely needs `dialect check`
  /// to flag the missing metadata.
  final List<String> keysMissingNamespace;
}
