import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../project/dialect_project.dart';
import '../templates/describe_plan_md.dart';
import '../templates/plan_render.dart';

/// `dialect describe` — AI-pointer flow.
///
/// Writes a structured instruction file to `.dialect/describe-plan.md`
/// telling the user's AI to scan callsites and fill any missing
/// `@description` (and where appropriate `context` / `placeholders`)
/// on entries in the source ARB. Dialect does not open source code; the
/// plan tells the agent where to look (`--path`, defaults to the
/// project root).
class DescribeCommand extends Command<int> {
  DescribeCommand() {
    argParser.addOption(
      'path',
      help:
          'Path the AI should scan for callsites (e.g. `lib/`). Defaults to the project root.',
    );
  }

  @override
  String get name => 'describe';

  @override
  String get description =>
      'Write an AI-pointer plan that backfills @description fields from callsites.';

  @override
  String get invocation => 'dialect describe [--path <path>] [project-root]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final pathOpt = results['path'] as String?;
    final rest = results.rest;

    if (rest.length > 1) {
      stderr.writeln('dialect describe takes at most one positional argument.');
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

    final path = (pathOpt == null || pathOpt.isEmpty)
        ? '(the project root)'
        : pathOpt;
    final tokens = {...commonPlanTokens(project), 'PATH': path};
    final rendered = renderPlanTemplate(describePlanMdTemplate, tokens);

    final planPath = p.join(root, '.dialect', 'describe-plan.md');
    final planFile = File(planPath);
    planFile.parent.createSync(recursive: true);
    planFile.writeAsStringSync(rendered);

    final relativePath = p.relative(planPath, from: Directory.current.path);
    stdout.writeln('Wrote describe plan to $relativePath');
    stdout.writeln(
      '  Next: open your AI tool (Claude Code, Cursor, Cline, Copilot, …)',
    );
    stdout.writeln('  and ask it to follow the plan:');
    stdout.writeln('    "Read $relativePath and execute the steps."');
    return 0;
  }
}
