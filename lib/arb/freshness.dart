import 'arb_file.dart';
import 'source_hash.dart';

/// Translation freshness — the change-half of the sync loop.
///
/// Each translation records the `source_hash` (per `dialect/spec/source_hash.md`)
/// of the source value it was written against. When the English source later
/// changes, the stored hash no longer matches and the translation is **stale**
/// — it needs re-translating or re-reviewing. A translation with no stored
/// hash is **untracked** (provenance unknown), not stale: we only start
/// tracking from the moment a value is stamped, so adoption never floods a
/// project with false positives.
///
/// Provenance lives on the value, committed in the translation ARB. In Cloud
/// (v1.3) the same hash is a column on the translation row, carried by
/// `push`/`pull` — the contract is identical across local-only, self-host,
/// and Cloud.

/// `{ key: sha256-16(source value) }` for every source entry.
Map<String, String> computeSourceHashes(ArbFile source) => {
  for (final e in source.entries) e.key: computeSourceHash(e.value),
};

/// True when [entry] records a `source_hash` that no longer matches the
/// current source. Entries without a stored hash, or whose key is absent
/// from [sourceHashes], are untracked — not stale.
bool isStaleEntry(ArbEntry entry, Map<String, String> sourceHashes) {
  final stored = entry.metadata?.sourceHash;
  if (stored == null) return false;
  final current = sourceHashes[entry.key];
  return current != null && current != stored;
}

/// Normalize a translation ARB for `dialect check --fix`:
///
/// - **Strip descriptive metadata** (`namespace`, `description`, `context`,
///   `placeholders`) — that belongs only in the source ARB.
/// - **Preserve state metadata** (`locked`, `source_hash`) — provenance and
///   human-approval are properties of the translation value.
/// - **Stamp `source_hash`** = current source hash onto unlocked entries that
///   have a value but no hash yet. New translations (just written by an AI or
///   `dialect pull`) become tracked-as-fresh; existing hashes are never
///   overwritten, so a stale translation stays stale until it's actually
///   re-translated (which clears the hash) or locked (which re-stamps it).
///
/// Locked entries are left to the lock/unlock flow — never auto-stamped.
///
/// Set [stamp] to false to normalize formatting *without* adding hashes to
/// entries that lack one. This is the authoring pass: the first `--fix` on a
/// brand-new locale otherwise turns a reviewable ~280-line file of plain
/// `"key": "value"` pairs into ~1,300 lines, because every key gains a
/// three-line `@key` block — swamping the human review of the one file whose
/// *content* most deserves reading. Existing hashes are always preserved;
/// this only defers creating new ones to the next run.
///
/// We deliberately did **not** solve this by moving hashes to a sidecar file
/// (`.vi.hashes.json`). The ARB would stop being self-describing, and two
/// files that must agree about the same keys is a drift bug waiting to
/// happen — a worse trade than one large diff on one run.
ArbFile normalizeTranslation(
  ArbFile arb,
  Map<String, String> sourceHashes, {
  bool stamp = true,
}) {
  final entries = <ArbEntry>[];
  for (final e in arb.entries) {
    final locked = e.metadata?.locked ?? false;
    var hash = e.metadata?.sourceHash;

    if (stamp &&
        !locked &&
        hash == null &&
        e.value.isNotEmpty &&
        sourceHashes.containsKey(e.key)) {
      hash = sourceHashes[e.key];
    }

    final keepMetadata = locked || hash != null;
    entries.add(
      ArbEntry(
        key: e.key,
        value: e.value,
        metadata: keepMetadata
            ? ArbMetadata(locked: locked, sourceHash: hash)
            : null,
      ),
    );
  }

  return ArbFile(
    locale: arb.locale,
    entries: entries,
    fileMetadata: arb.fileMetadata,
    orphanMetadata: const {},
    entryLines: arb.entryLines,
    sourcePath: arb.sourcePath,
  );
}
