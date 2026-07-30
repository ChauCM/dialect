import 'dart:io';

import 'package:args/command_runner.dart';

import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../arb/source_hash.dart';
import '../project/dialect_project.dart';
import 'key_selection.dart';

/// `dialect lock <key>...` — mark translations as human-approved so nothing
/// rewrites them, and record what was approved.
///
/// A lock is the answer to "this value is deliberate, leave it alone" — most
/// often a translation that is *intentionally identical* to the source (a
/// brand name, an abbreviation, a term this locale genuinely borrows), which
/// `source_equality` would otherwise flag on every run, and which
/// `dialect translate` would otherwise keep offering to re-translate.
///
/// The lock is only meaningful with provenance: `locked: true` alone cannot
/// say *what* a human approved, so `lock_integrity` rejects a bare lock. This
/// command therefore always writes the pair — `locked: true` plus the current
/// `source_hash` — which is exactly the two-part gesture that previously
/// required hand-editing `@key` blocks inside a file the CLI otherwise owns.
/// That hand-edit was the last routine manual touch in the workflow.
///
/// Re-running on an already-locked key whose English has since moved
/// **re-locks it against the current source** — the "I re-reviewed it and it
/// still holds" gesture that clears a locked + stale entry. That is the same
/// motion [AcceptCommand] performs for unlocked translations; the difference
/// is only whether the entry stays pinned afterwards.
///
/// `--remove` is the inverse (unlock), keeping the hash so the entry's
/// freshness is still tracked.
///
/// The subject is a set, not a key: hand-authored copy arrives as a page or a
/// screen, so `dialect lock a b c` and `dialect lock --namespace web` both
/// work. Locale selection is `--locale` (see [resolveSelection]).
class LockCommand extends Command<int> {
  LockCommand() {
    argParser
      ..addOption(
        'root',
        help:
            'Project root (the directory containing dialect/). '
            'Defaults to the current directory.',
        valueHelp: 'path',
      )
      ..addOption(
        'namespace',
        abbr: 'n',
        help:
            'Act on every source key in this namespace, instead of (or as '
            'well as) the keys named on the command line. Hand-authored copy '
            'arrives a page at a time, and a namespace is how the source '
            'already groups a page. A lock asserts a human approved the '
            'value, so this asserts it for every key in the namespace — read '
            'the count it reports back.',
        valueHelp: 'name',
      )
      ..addOption(
        'locale',
        abbr: 'l',
        help:
            'Act on one target locale. Default: every target locale that '
            'carries the key.',
        valueHelp: 'locale',
      )
      ..addFlag(
        'remove',
        negatable: false,
        help:
            'Unlock instead of lock. Keeps the recorded source_hash so the '
            'entry still reports staleness normally.',
      );
  }

  @override
  String get name => 'lock';

  @override
  String get description =>
      'Mark a translation as human-approved (and stamp what was approved), '
      'or --remove to unlock it.';

  @override
  String get invocation =>
      'dialect lock <key>... [--namespace <name>] [--locale <locale>]';

  @override
  Future<int> run() async {
    final remove = argResults!.flag('remove');
    final root = argResults!.option('root') ?? Directory.current.path;
    final verb = remove ? 'unlock' : 'lock';

    final DialectProject project;
    try {
      project = DialectProject.load(root);
    } on FileSystemException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln('Run `dialect init` first, or run from the project root.');
      return 66;
    } on FormatException catch (e) {
      stderr.writeln('dialect.yaml or an ARB file is malformed:');
      stderr.writeln('  ${e.message}');
      return 65;
    }

    final KeySelection selection;
    try {
      selection = resolveSelection(
        project: project,
        command: 'lock',
        positionals: argResults!.rest,
        namespace: argResults!.option('namespace'),
        locale: argResults!.option('locale'),
      );
    } on SelectionFailure catch (f) {
      f.lines.forEach(stderr.writeln);
      return f.code;
    }

    // key -> locales, per outcome. Grouping this way keeps the report the
    // same shape for one key and for a whole namespace.
    // locale -> (key -> rewritten entry). Collected first and flushed once
    // per file: writing inside the loop re-serialized the stale in-memory ARB
    // each time, so with more than one key only the last one survived.
    final pending = <String, Map<String, ArbEntry>>{};

    final changed = <String, Set<String>>{};
    final unchanged = <String, Set<String>>{};
    final skipped = <String, Set<String>>{};

    for (final key in selection.keys) {
      final hash = computeSourceHash(project.source.entryFor(key)!.value);
      for (final locale in selection.locales) {
        final arb = project.translations[locale]!;
        final entry = arb.entryFor(key);
        if (entry == null || entry.value.isEmpty) {
          // Locking asserts a human approved a specific value; there is no
          // value here to approve. That's missing_keys / empty_values.
          skipped.putIfAbsent(key, () => <String>{}).add(locale);
          continue;
        }
        final wasLocked = entry.metadata?.locked ?? false;
        final hashCurrent = entry.metadata?.sourceHash == hash;
        if (remove) {
          if (!wasLocked) {
            unchanged.putIfAbsent(key, () => <String>{}).add(locale);
            continue;
          }
        } else {
          // Already locked against the *current* source — nothing to restate.
          // A locked-but-stale entry falls through and is re-locked.
          if (wasLocked && hashCurrent) {
            unchanged.putIfAbsent(key, () => <String>{}).add(locale);
            continue;
          }
        }
        pending.putIfAbsent(locale, () => <String, ArbEntry>{})[key] = ArbEntry(
          key: key,
          value: entry.value,
          metadata: ArbMetadata(locked: !remove, sourceHash: hash),
        );
        changed.putIfAbsent(key, () => <String>{}).add(locale);
      }
    }

    for (final e in pending.entries) {
      _flush(project.translations[e.key]!, e.value);
    }

    if (changed.isEmpty && unchanged.isEmpty && skipped.isNotEmpty) {
      stderr.writeln(
        'Nothing to $verb: ${describeKeyCount(skipped.length)} '
        '(${previewKeys(skipped.keys)}) have no translation yet in '
        '${selection.locales.join(', ')}. Translate them first.',
      );
      return 65;
    }

    if (changed.isNotEmpty) {
      stdout.writeln(
        remove
            ? '✓ unlocked ${describeKeyCount(changed.length)} '
                  '(source_hash kept, so staleness is still tracked):'
            : '✓ locked ${describeKeyCount(changed.length)} against the '
                  'current source:',
      );
      stdout.writeln('    ${previewKeys(changed.keys)}');
      stdout.writeln('    in ${_localesOf(changed).join(', ')}');
    }
    if (unchanged.isNotEmpty) {
      stdout.writeln(
        remove
            ? '  already unlocked: ${describeKeyCount(unchanged.length)}'
            : '  already locked and current: '
                  '${describeKeyCount(unchanged.length)}',
      );
    }
    if (skipped.isNotEmpty) {
      stdout.writeln(
        '  skipped (no translation yet): '
        '${describeKeyCount(skipped.length)} — ${previewKeys(skipped.keys)}',
      );
    }
    return 0;
  }

  /// Every locale touched across [byKey], sorted — so the summary can say
  /// "in vi" once instead of repeating it per key.
  List<String> _localesOf(Map<String, Set<String>> byKey) {
    final locales = <String>{for (final s in byKey.values) ...s}.toList()
      ..sort();
    return locales;
  }

  /// Apply every [replacements] entry to [arb] and re-emit the file once.
  /// Values are never touched — the replacement carries the original value and
  /// only its metadata differs. Writing the lock flag and the hash together is
  /// what keeps `lock_integrity` satisfied; splitting them is precisely the
  /// mistake that rule exists to catch.
  void _flush(ArbFile arb, Map<String, ArbEntry> replacements) {
    final entries = [for (final e in arb.entries) replacements[e.key] ?? e];
    final rewritten = ArbFile(
      locale: arb.locale,
      entries: entries,
      fileMetadata: arb.fileMetadata,
      entryLines: arb.entryLines,
      sourcePath: arb.sourcePath,
    );
    final path = arb.sourcePath;
    if (path != null) {
      File(path).writeAsStringSync(ArbWriter.encode(rewritten));
    }
  }
}
