import 'dart:io';

import 'package:args/command_runner.dart';

import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../arb/source_hash.dart';
import '../project/dialect_project.dart';

/// `dialect lock <key> [locale]` — mark a translation as human-approved so
/// nothing rewrites it, and record what was approved.
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
      'dialect lock <key> [locale]   # [locale] '
      'defaults to every target locale';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final remove = argResults!.flag('remove');
    if (rest.isEmpty || rest.length > 2) {
      stderr.writeln('lock takes <key> and an optional [locale].');
      stderr.writeln('  e.g. dialect lock brandTagline');
      stderr.writeln('       dialect lock brandTagline vi');
      stderr.writeln('       dialect lock brandTagline vi --remove');
      return 64;
    }
    final key = rest.first;
    final onlyLocale = rest.length == 2 ? rest[1] : null;
    final root = argResults!.option('root') ?? Directory.current.path;

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

    final sourceEntry = project.source.entryFor(key);
    if (sourceEntry == null) {
      stderr.writeln(
        'Key `$key` is not in the source ARB — nothing to lock against. '
        'Add it to dialect/source first.',
      );
      return 65;
    }
    final hash = computeSourceHash(sourceEntry.value);

    final Iterable<String> locales;
    if (onlyLocale != null) {
      if (!project.translations.containsKey(onlyLocale)) {
        stderr.writeln(
          'Locale `$onlyLocale` is not a configured target locale. '
          'Targets: ${project.translations.keys.join(', ')}.',
        );
        return 64;
      }
      locales = [onlyLocale];
    } else {
      locales = project.translations.keys;
    }

    final changed = <String>[];
    final unchanged = <String>[];
    final skipped = <String>[];

    for (final locale in locales) {
      final arb = project.translations[locale]!;
      final entry = arb.entryFor(key);
      if (entry == null || entry.value.isEmpty) {
        // Locking asserts a human approved a specific value; there is no
        // value here to approve. That's missing_keys / empty_values.
        skipped.add(locale);
        continue;
      }
      final wasLocked = entry.metadata?.locked ?? false;
      final hashCurrent = entry.metadata?.sourceHash == hash;
      if (remove) {
        if (!wasLocked) {
          unchanged.add(locale);
          continue;
        }
      } else {
        // Already locked against the *current* source — nothing to restate.
        // A locked-but-stale entry falls through and is re-locked.
        if (wasLocked && hashCurrent) {
          unchanged.add(locale);
          continue;
        }
      }
      _write(arb, key, locked: !remove, hash: hash);
      changed.add(locale);
    }

    if (changed.isEmpty && unchanged.isEmpty && skipped.isNotEmpty) {
      stderr.writeln(
        'Key `$key` has no translation to ${remove ? 'unlock' : 'lock'} in '
        '${skipped.join(', ')} (missing or empty). Translate it first.',
      );
      return 65;
    }

    if (changed.isNotEmpty) {
      stdout.writeln(
        remove
            ? '✓ unlocked `$key` — ${changed.join(', ')} '
                  '(source_hash kept, so staleness is still tracked).'
            : '✓ locked `$key` — ${changed.join(', ')} '
                  'approved against the current source.',
      );
    }
    if (unchanged.isNotEmpty) {
      stdout.writeln(
        remove
            ? '  already unlocked: ${unchanged.join(', ')}'
            : '  already locked and current: ${unchanged.join(', ')}',
      );
    }
    if (skipped.isNotEmpty) {
      stdout.writeln('  skipped (no translation yet): ${skipped.join(', ')}');
    }
    return 0;
  }

  /// Rewrite [key]'s metadata in [arb], setting the lock flag and stamping
  /// [hash]. The value is never touched. Writing the hash alongside the lock
  /// is what keeps `lock_integrity` satisfied — the two are one gesture, and
  /// splitting them is precisely the mistake that rule exists to catch.
  void _write(
    ArbFile arb,
    String key, {
    required bool locked,
    required String hash,
  }) {
    final entries = <ArbEntry>[];
    for (final e in arb.entries) {
      if (e.key != key) {
        entries.add(e);
        continue;
      }
      entries.add(
        ArbEntry(
          key: e.key,
          value: e.value,
          metadata: ArbMetadata(locked: locked, sourceHash: hash),
        ),
      );
    }
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
