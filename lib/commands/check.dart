import 'dart:io';

import 'package:args/command_runner.dart';

import '../checks/ack.dart';
import '../checks/check_runner.dart';
import '../checks/fixer.dart';
import '../checks/report.dart';
import '../project/dialect_project.dart';
import '../state/state_store.dart';

class CheckCommand extends Command<int> {
  CheckCommand() {
    argParser
      ..addFlag(
        'strict',
        negatable: false,
        help: 'Promote warnings to errors (CI mode).',
      )
      ..addFlag(
        'strict-length',
        negatable: false,
        help:
            'Also promote the length-family warnings (length-ratio, '
            'width-budget) to errors. Independent of --strict because these '
            'length heuristics are softer conventions than the other checks.',
      )
      ..addFlag(
        'fix',
        negatable: false,
        help:
            'Normalize ARB files in place: sort keys, hoist @@locale, place '
            'each @key block after its key, strip descriptive metadata from '
            'translations (keeping locked + source_hash), stamp source_hash '
            'provenance onto unlocked translations, drop orphan @key blocks.',
      )
      ..addFlag(
        'stamp',
        defaultsTo: true,
        help:
            'With --fix, stamp source_hash provenance onto unlocked '
            'translations that lack it. Use --no-stamp for the authoring pass '
            'on a brand-new locale, so the first review stays a readable diff '
            'of translations instead of one @key block per key; the next '
            '--fix stamps them. Existing hashes are always preserved.',
      )
      ..addOption(
        'ack',
        help:
            'Acknowledge a soft-mode warning so it stops surfacing: '
            '--ack <rule>:<locale>:<key> (e.g. '
            'source_equality:vi:settingsEmailLabel). Writes '
            '.dialect/state.json; re-fires if the source/translation changes.',
        valueHelp: 'rule:locale:key',
      )
      ..addOption(
        'note',
        help: 'Optional justification stored alongside --ack.',
      );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Validate translation completeness and correctness.';

  @override
  String get invocation =>
      'dialect check [path]   # path defaults to the current directory';

  @override
  Future<int> run() async {
    final results = argResults!;
    final rest = results.rest;
    if (rest.length > 1) {
      stderr.writeln('check takes at most one positional argument.');
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

    final ackId = results.option('ack');
    if (ackId != null) {
      return _writeAck(project, root, ackId, results.option('note'));
    }

    final stamp = results.flag('stamp');
    if (!stamp && !results.flag('fix')) {
      // A flag that silently does nothing is worse than one that says so.
      stdout.writeln(
        '! --no-stamp only affects --fix; nothing to skip on a read-only '
        'check.',
      );
    }

    if (results.flag('fix')) {
      final report = Fixer.fix(project, stamp: stamp);
      if (report.count == 0) {
        stdout.writeln('✓ dialect check --fix: every ARB is already canonical');
      } else {
        stdout.writeln(
          '✓ dialect check --fix: normalized ${report.count} file(s):',
        );
        for (final path in report.changedFiles) {
          stdout.writeln('  $path');
        }
      }
      if (!stamp) {
        stdout.writeln(
          '  (--no-stamp: left new translations unstamped — run '
          '`dialect check --fix` once the values are reviewed.)',
        );
      }
      // After --fix, re-load the project so the check pass runs against
      // the rewritten files. This catches issues that the fix can't
      // resolve (missing keys, placeholder mismatches, etc.).
      final reloaded = DialectProject.load(root);
      final outcome = applyAcks(
        runChecks(reloaded),
        reloaded,
        StateStore.load(root),
      );
      return CheckReport.write(
        outcome.result,
        strict: results.flag('strict'),
        strictLength: results.flag('strict-length'),
        suppressed: outcome.suppressed,
        staleAcks: outcome.staleAcks,
      );
    }

    final outcome = applyAcks(
      runChecks(project),
      project,
      StateStore.load(root),
    );
    return CheckReport.write(
      outcome.result,
      strict: results.flag('strict'),
      strictLength: results.flag('strict-length'),
      suppressed: outcome.suppressed,
      staleAcks: outcome.staleAcks,
    );
  }

  /// Write (or refresh) an acknowledgement for [ackId] of the form
  /// `<rule>:<locale>:<key>`. The fingerprint is computed from the current
  /// source/translation value, so the ack auto-expires when that value
  /// changes. Structural rules are rejected — those are correctness
  /// failures, not heuristics.
  int _writeAck(
    DialectProject project,
    String root,
    String ackId,
    String? note,
  ) {
    final parts = ackId.split(':');
    if (parts.length != 3 || parts.any((p) => p.isEmpty)) {
      stderr.writeln(
        'Invalid --ack id `$ackId`. Expected `<rule>:<locale>:<key>` '
        '(e.g. source_equality:vi:settingsEmailLabel).',
      );
      return 64;
    }
    final rule = parts[0];
    final locale = parts[1];
    final key = parts[2];

    if (!isAckableRule(rule)) {
      stderr.writeln(
        'Rule `$rule` is not acknowledgeable. Only the heuristic rules '
        '(source_equality, glossary, untranslated_english, length_ratio, '
        'width_budget) can be acked; structural issues are correctness '
        'failures — fix the underlying problem instead.',
      );
      return 64;
    }

    final fingerprint = ackFingerprint(
      rule,
      locale == 'source' ? null : locale,
      key,
      project,
    );
    if (fingerprint == null) {
      stderr.writeln(
        'Could not resolve `$key`'
        '${locale == 'source' ? '' : ' (locale `$locale`)'} to a value to '
        'fingerprint. Is the key present in the source'
        '${locale == 'source' ? '' : '/translation'} ARB?',
      );
      return 65;
    }

    final state = StateStore.load(root);
    state.checks[ackId] = AckRecord(
      acknowledged: fingerprint,
      acknowledgedAt: DateTime.now().toUtc().toIso8601String(),
      note: note,
    );
    state.save(root);

    stdout.writeln('✓ acknowledged $ackId');
    stdout.writeln('  fingerprint: $fingerprint');
    if (note != null) stdout.writeln('  note: $note');
    stdout.writeln(
      '  This warning stays hidden until the '
      '${isSourceHashed(rule) ? 'source' : 'translation'} value changes.',
    );
    return 0;
  }
}
