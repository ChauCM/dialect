import 'dart:io';

import 'package:args/command_runner.dart';

import '../arb/arb_file.dart';
import '../arb/arb_writer.dart';
import '../arb/source_hash.dart';
import '../project/dialect_project.dart';
import 'key_selection.dart';

/// `dialect accept <key>...` — re-bless existing translations as current
/// after the English source changed *without* re-translating them.
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
/// The subject is a set, not a key: an English edit that touches a screen
/// leaves a screen's worth of stale translations, so `dialect accept a b c`
/// and `dialect accept --namespace web` both work. Locale selection is
/// `--locale` (see [resolveSelection]).
///
/// It deliberately does NOT re-translate, and it will not stamp a key that is
/// missing or empty in a translation (that's `missing_keys` / `empty_values`
/// to resolve, not a review). Accepting is an explicit human assertion that
/// the translation is correct — there is no automatic byte-identical
/// re-stamp, because an unchanged translation says nothing about whether it
/// still matches the changed English.
class AcceptCommand extends Command<int> {
  AcceptCommand() {
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
            'well as) the keys named on the command line.',
        valueHelp: 'name',
      )
      ..addOption(
        'locale',
        abbr: 'l',
        help:
            'Act on one target locale. Default: every target locale that '
            'carries the key.',
        valueHelp: 'locale',
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
      'dialect accept <key>... [--namespace <name>] [--locale <locale>]';

  @override
  Future<int> run() async {
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

    final KeySelection selection;
    try {
      selection = resolveSelection(
        project: project,
        command: 'accept',
        positionals: argResults!.rest,
        namespace: argResults!.option('namespace'),
        locale: argResults!.option('locale'),
      );
    } on SelectionFailure catch (f) {
      f.lines.forEach(stderr.writeln);
      return f.code;
    }

    // locale -> (key -> rewritten entry). Collected first and flushed once
    // per file: writing inside the loop re-serialized the stale in-memory ARB
    // each time, so with more than one key only the last one survived.
    final pending = <String, Map<String, ArbEntry>>{};

    final restamped = <String, Set<String>>{};
    final alreadyFresh = <String, Set<String>>{};
    final skipped = <String, Set<String>>{};

    for (final key in selection.keys) {
      final hash = computeSourceHash(project.source.entryFor(key)!.value);
      for (final locale in selection.locales) {
        final arb = project.translations[locale]!;
        final entry = arb.entryFor(key);
        if (entry == null || entry.value.isEmpty) {
          // No translation to bless — that's a missing_keys / empty_values
          // concern, not something `accept` invents a value for.
          skipped.putIfAbsent(key, () => <String>{}).add(locale);
          continue;
        }
        if (entry.metadata?.sourceHash == hash) {
          alreadyFresh.putIfAbsent(key, () => <String>{}).add(locale);
          continue;
        }
        pending.putIfAbsent(locale, () => <String, ArbEntry>{})[key] = ArbEntry(
          key: key,
          value: entry.value,
          metadata: ArbMetadata(
            locked: entry.metadata?.locked ?? false,
            sourceHash: hash,
          ),
        );
        restamped.putIfAbsent(key, () => <String>{}).add(locale);
      }
    }

    for (final e in pending.entries) {
      _flush(project.translations[e.key]!, e.value);
    }

    if (restamped.isEmpty && alreadyFresh.isEmpty && skipped.isNotEmpty) {
      stderr.writeln(
        'Nothing to accept: ${describeKeyCount(skipped.length)} '
        '(${previewKeys(skipped.keys)}) have no translation yet in '
        '${selection.locales.join(', ')}. Translate them first.',
      );
      return 65;
    }

    if (restamped.isNotEmpty) {
      final locales = <String>{for (final s in restamped.values) ...s}.toList()
        ..sort();
      stdout.writeln(
        '✓ accepted ${describeKeyCount(restamped.length)} — re-stamped as '
        'current in ${locales.join(', ')}:',
      );
      stdout.writeln('    ${previewKeys(restamped.keys)}');
    }
    if (alreadyFresh.isNotEmpty) {
      stdout.writeln(
        '  already current: ${describeKeyCount(alreadyFresh.length)}',
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

  /// Apply every [replacements] entry to [arb] and re-emit the file once.
  /// Each replacement preserves the value and the `locked` flag and carries
  /// only a new hash. Unlike `normalizeTranslation` (which never overwrites an
  /// existing hash), this deliberately replaces a stale one — that is the
  /// whole point of accept.
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
