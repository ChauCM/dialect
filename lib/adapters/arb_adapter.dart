import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../config/dialect_config.dart';

/// ARB-passthrough adapter. The only adapter Dialect ships in v1.0 —
/// every other platform (Apple `.strings`, Android `strings.xml`,
/// `flat-json`, `icu-json`) is parked for v1.1.
///
/// Two transforms happen during sync:
///
/// 1. **Namespace filter.** Only keys whose namespace prefix (before the
///    first `.`) appears in [PlatformConfig.namespaces] are included. An
///    empty namespaces list disables the filter — every key passes.
/// 2. **Metadata stripping.** Source ARBs keep their `@key` blocks
///    intact (Flutter's `gen_l10n` reads them). Translation ARBs are
///    key/value-only by convention; if a translation accidentally
///    accumulated `@key` blocks, the adapter strips them. (Dialect
///    parses these into [ArbFile.entries[].metadata] regardless; the
///    adapter decides whether to emit them based on whether this is the
///    source or a translation.)
///
/// Output is always [ArbWriter] canonical form — that's the idempotency
/// contract (`sync` twice = same bytes). `dialect check --fix` reuses
/// the same writer, so a synced ARB run back through `--fix` is a
/// no-op.
///
/// **The adapter does not modify input ARBs.** No "auto-fix" during
/// sync; that's `dialect check --fix`'s job. If the user's source ARB
/// isn't canonical, sync output is still canonical (writer-driven), but
/// the input file is untouched.
class ArbAdapter {
  const ArbAdapter._();

  /// Apply the namespace filter and strip translation metadata, returning
  /// a new [ArbFile] ready to hand to [ArbWriter].
  ///
  /// [isSource] preserves `@key` metadata when true; false strips it.
  static ArbFile prepare(
    ArbFile arb, {
    required PlatformConfig platform,
    required bool isSource,
  }) {
    final namespaces = platform.namespaces;
    final keepAll = namespaces.isEmpty;
    final ns = namespaces.toSet();

    final entries = <ArbEntry>[];
    for (final entry in arb.entries) {
      if (!keepAll) {
        final nsPrefix = entry.namespace;
        if (nsPrefix == null || !ns.contains(nsPrefix)) continue;
      }
      entries.add(
        isSource ? entry : ArbEntry(key: entry.key, value: entry.value),
      );
    }

    return ArbFile(
      locale: arb.locale,
      entries: entries,
      fileMetadata: arb.fileMetadata,
      // Orphans are never emitted — same contract as the writer.
      orphanMetadata: const {},
      // Line numbers are tied to the source file; meaningless after
      // namespace filtering. Drop them.
      entryLines: const {},
      sourcePath: arb.sourcePath,
    );
  }

  /// Render an [ArbFile] to canonical bytes via [ArbWriter].
  static String encode(ArbFile arb) => ArbWriter.encode(arb);

  /// Filename convention for v1.0: `app_<locale>.arb`. Matches Flutter's
  /// `gen_l10n` default. **v1.1** will spec a configurable pattern under
  /// `platforms.<p>.filename_pattern` (e.g. `app_{locale}.arb` vs
  /// `{locale}.arb` vs `intl_{locale}.arb`). Hard-coded for now keeps
  /// v1.0 ergonomic for the dominant case.
  static String filenameFor(String locale) => 'app_$locale.arb';
}
