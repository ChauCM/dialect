import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../project/dialect_project.dart';
import '../templates/import_plan_md.dart';
import '../templates/plan_render.dart';

/// `dialect import` — AI-pointer flow.
///
/// Writes a structured instruction file to
/// `.dialect/import-plan.md` and tells the user to point their AI tool
/// at it. Dialect itself never opens source files at `--path`; that's
/// the agent's job. The agent reads the plan, the convention
/// (`dialect/dialect.yaml`), and the user's source under `--path`, and
/// produces the updated source ARB.
class ImportCommand extends Command<int> {
  ImportCommand() {
    argParser
      ..addOption(
        'from',
        help: 'Source format to import from.',
        allowed: const ['arb'],
        defaultsTo: 'arb',
      )
      ..addOption(
        'path',
        help: 'Path to the source files (e.g. `lib/l10n/`) to import.',
      );
  }

  @override
  String get name => 'import';

  @override
  String get description =>
      'Write an AI-pointer plan that imports existing strings into the Dialect convention.';

  @override
  String get invocation =>
      'dialect import --from arb --path <path> [project-root]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final from = results['from'] as String;
    final path = results['path'] as String?;
    final rest = results.rest;

    if (path == null || path.isEmpty) {
      stderr.writeln('dialect import: --path is required.');
      stderr.writeln('  Example: dialect import --from arb --path lib/l10n/');
      return 64;
    }
    if (rest.length > 1) {
      stderr.writeln('dialect import takes at most one positional argument.');
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

    final tokens = {...commonPlanTokens(project), 'FROM': from, 'PATH': path};
    final rendered = renderPlanTemplate(importPlanMdTemplate, tokens);

    final planPath = p.join(root, '.dialect', 'import-plan.md');
    final planFile = File(planPath);
    planFile.parent.createSync(recursive: true);
    planFile.writeAsStringSync(rendered);

    final relativePath = p.relative(planPath, from: Directory.current.path);
    stdout.writeln('Wrote import plan to $relativePath');
    stdout.writeln(
      '  Next: open your AI tool (Claude Code, Cursor, Cline, Copilot, …)',
    );
    stdout.writeln('  and ask it to follow the plan:');
    stdout.writeln('    "Read $relativePath and execute the steps."');
    return 0;
  }
}
