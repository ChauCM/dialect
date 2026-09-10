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
      )
      ..addFlag(
        'list-acks',
        negatable: false,
        help:
            'Classify every acknowledgement in .dialect/state.json — live, '
            'inert, lapsed, orphaned — instead of running the check. An ack '
            'whose warning has stopped firing is invisible to a normal run, '
            'so this is the only way to see one.',
      )
      ..addFlag(
        'prune-acks',
        negatable: false,
        help:
            'Delete acknowledgements that no longer adjudicate anything '
            '(lapsed, orphaned, or unparseable). Entries whose fingerprint '
            'still matches are kept.',
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

    final listAcks = results.flag('list-acks');
    final pruneAcks = results.flag('prune-acks');
    if (listAcks || pruneAcks) {
      return _auditAcks(project, root, prune: pruneAcks);
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
        '(${ackableRuleNames.join(", ")}) can be acked; structural issues '
        'are correctness failures — fix the underlying problem instead.',
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
      '${isSourceHashed(rule, locale: locale) ? 'source' : 'translation'} '
      'value changes.',
    );
    stdout.writeln(
      '  Commit .dialect/state.json — a teammate or a CI run that checks out '
      'this branch without it will see the warning you just adjudicated.',
    );
    return 0;
  }

  /// Print (and optionally prune) the acknowledgement ledger.
  ///
  /// The classification runs against the **raw** check result, before
  /// suppression, because that is the only place the distinction between a
  /// live ack and an inert one exists: both match their fingerprint, and only
  /// one of them hid something.
  int _auditAcks(DialectProject project, String root, {required bool prune}) {
    final state = StateStore.load(root);
    if (state.checks.isEmpty) {
      stdout.writeln('No acknowledgements in .dialect/state.json.');
      return 0;
    }

    final audits = auditAcks(runChecks(project), project, state);
    const labels = {
      AckStatus.live: 'live      ',
      AckStatus.inert: 'inert     ',
      AckStatus.lapsed: 'lapsed    ',
      AckStatus.orphaned: 'orphaned  ',
      AckStatus.invalid: 'invalid   ',
    };

    for (final audit in audits) {
      stdout.writeln('  ${labels[audit.status]}${audit.id}');
      final note = audit.record.note;
      if (note != null && note.isNotEmpty) stdout.writeln('             $note');
    }

    final counts = <AckStatus, int>{};
    for (final a in audits) {
      counts[a.status] = (counts[a.status] ?? 0) + 1;
    }
    final dead = audits.where((a) => a.isDead).toList();

    stdout.writeln();
    stdout.writeln(
      '${audits.length} acknowledgement(s): '
      '${counts[AckStatus.live] ?? 0} live, '
      '${counts[AckStatus.inert] ?? 0} inert, '
      '${counts[AckStatus.lapsed] ?? 0} lapsed, '
      '${counts[AckStatus.orphaned] ?? 0} orphaned, '
      '${counts[AckStatus.invalid] ?? 0} invalid.',
    );

    if (!prune) {
      if (dead.isNotEmpty) {
        stdout.writeln(
          '! ${dead.length} no longer adjudicate anything. They read like '
          'live rulings in a diff and cannot be re-derived — '
          '`dialect check --prune-acks` deletes them.',
        );
      }
      if ((counts[AckStatus.inert] ?? 0) > 0) {
        stdout.writeln(
          '  inert = the fingerprint still matches but nothing fired for it '
          'this run. Kept: the ruling is still true of the current text.',
        );
      }
      return 0;
    }

    if (dead.isEmpty) {
      stdout.writeln('✓ nothing to prune.');
      return 0;
    }
    for (final audit in dead) {
      state.checks.remove(audit.id);
    }
    state.save(root);
    stdout.writeln('✓ pruned ${dead.length} acknowledgement(s).');
    return 0;
  }
}
