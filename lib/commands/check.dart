import 'dart:io';

import 'package:args/command_runner.dart';

import '../checks/check_runner.dart';
import '../checks/fixer.dart';
import '../checks/report.dart';
import '../project/dialect_project.dart';

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
        help: 'Also promote length-ratio warnings to errors (M8).',
      )
      ..addFlag(
        'fix',
        negatable: false,
        help:
            'Normalize ARB files in place: sort keys, hoist @@locale, '
            'place each @key block after its key, strip @key blocks from '
            'translation files, drop orphan @key blocks.',
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

    if (results.flag('fix')) {
      final report = Fixer.fix(project);
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
      // After --fix, re-load the project so the check pass runs against
      // the rewritten files. This catches issues that the fix can't
      // resolve (missing keys, placeholder mismatches, etc.).
      final reloaded = DialectProject.load(root);
      final result = runChecks(reloaded);
      return CheckReport.write(result, strict: results.flag('strict'));
    }

    final result = runChecks(project);
    return CheckReport.write(result, strict: results.flag('strict'));
  }
}
