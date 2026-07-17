import 'dart:io';

import 'package:args/command_runner.dart';

import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../arb/source_hash.dart';
import '../project/dialect_project.dart';

/// `dialect accept <key> [locale]` — re-bless an existing translation as
/// current after the English source changed *without* re-translating it.
///
/// The staleness model (`stale_translation`) fires when the source value
/// moves after a translation was stamped: the stored `@key.source_hash` no
/// longer matches. When the existing translation is still correct despite the
/// wording change (e.g. a cosmetic English edit), the fix is not to
/// re-translate — it's to record "I reviewed this, it still holds." Before
/// this command the only way to do that was to hand-delete the stale
/// `@key.source_hash` block and run `check --fix`; `accept` is the
/// first-class gesture.
///
/// It re-stamps the current source hash onto the translation, touching only
/// provenance — never the value, never the `locked` flag. With no `[locale]`
/// it re-stamps every target locale that carries the key (a no-op for those
/// already fresh), so `dialect accept greetingLabel` blesses all stale
/// translations of that key at once.
///
/// It deliberately does NOT re-translate, and it will not stamp a key that is
/// missing or empty in a translation (that's `missing_keys` / `empty_values`
/// to resolve, not a review). Accepting is an explicit human assertion that
/// the translation is correct — there is no automatic byte-identical
/// re-stamp, because an unchanged translation says nothing about whether it
/// still matches the changed English.
class AcceptCommand extends Command<int> {
  AcceptCommand() {
    argParser.addOption(
      'root',
      help:
          'Project root (the directory containing dialect/). '
          'Defaults to the current directory.',
      valueHelp: 'path',
    );
  }

  @override
  String get name => 'accept';

  @override
  String get description =>
      'Re-stamp an existing translation as current after the English source '
      'changed, without re-translating it.';

  @override
  String get invocation =>
      'dialect accept <key> [locale]   # [locale] '
      'defaults to every target locale';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty || rest.length > 2) {
      stderr.writeln('accept takes <key> and an optional [locale].');
      stderr.writeln('  e.g. dialect accept composerStepCaptionHint');
      stderr.writeln('       dialect accept composerStepCaptionHint vi');
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
        'Key `$key` is not in the source ARB — nothing to accept against. '
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

    final restamped = <String>[];
    final alreadyFresh = <String>[];
    final skipped = <String>[];

    for (final locale in locales) {
      final arb = project.translations[locale]!;
      final entry = arb.entryFor(key);
      if (entry == null || entry.value.isEmpty) {
        // No translation to bless — that's a missing_keys / empty_values
        // concern, not something `accept` invents a value for.
        skipped.add(locale);
        continue;
      }
      if (entry.metadata?.sourceHash == hash) {
        alreadyFresh.add(locale);
        continue;
      }
      _restamp(arb, key, hash);
      restamped.add(locale);
    }

    if (restamped.isEmpty && alreadyFresh.isEmpty && skipped.isNotEmpty) {
      stderr.writeln(
        'Key `$key` has no translation to accept in '
        '${skipped.join(', ')} (missing or empty). Translate it first.',
      );
      return 65;
    }

    if (restamped.isNotEmpty) {
      stdout.writeln(
        '✓ accepted `$key` — re-stamped ${restamped.join(', ')} as current.',
      );
    }
    if (alreadyFresh.isNotEmpty) {
      stdout.writeln('  already current: ${alreadyFresh.join(', ')}');
    }
    if (skipped.isNotEmpty) {
      stdout.writeln('  skipped (no translation yet): ${skipped.join(', ')}');
    }
    return 0;
  }

  /// Overwrite the `source_hash` for [key] in [arb] to [hash], preserving the
  /// value and the `locked` flag, and re-emit the file. Unlike
  /// `normalizeTranslation` (which never overwrites an existing hash), this
  /// deliberately replaces a stale hash — that is the whole point of accept.
  void _restamp(ArbFile arb, String key, String hash) {
    final entries = <ArbEntry>[];
    for (final e in arb.entries) {
      if (e.key != key) {
        entries.add(e);
        continue;
      }
      final locked = e.metadata?.locked ?? false;
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
