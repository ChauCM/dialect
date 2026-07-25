import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../templates/agents_md_section.dart';
import '../templates/dialect_yaml.dart';
import '../templates/gitignore_snippet.dart';
import '../templates/glossary_yaml.dart';
import '../templates/init_plan_md.dart';
import '../templates/plan_render.dart';
import '../templates/source_arb.dart';
import '../version.dart';

/// `dialect init` — the agent-executable entry point.
///
/// Behavior is intentionally idempotent so re-running it (from the
/// terminal or from an AI agent) never gets stuck on "already scaffolded":
///
/// * **First run** (no `dialect/` directory): scaffold the workspace +
///   write `.dialect/init-plan.md` + write or update `AGENTS.md` +
///   append `.dialect/` to `.gitignore`.
/// * **Subsequent runs** (scaffold present): re-emit `.dialect/init-plan.md`
///   and refresh the `AGENTS.md` Dialect section. Touches the scaffold
///   files only with `--force`.
///
/// The CLI is self-teaching: its stdout ends with the exact chat message
/// the developer should paste into their AI agent to execute the plan.
class InitCommand extends Command<int> {
  InitCommand() {
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Overwrite existing dialect/ scaffold files.',
    );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Scaffold the dialect/ workspace and emit a playbook for your AI agent.';

  @override
  String get invocation =>
      'dialect init [path]   # path defaults to the current directory';

  @override
  Future<int> run() async {
    final results = argResults!;
    final force = results.flag('force');
    final rest = results.rest;

    if (rest.length > 1) {
      stderr.writeln('init takes at most one positional argument.');
      stderr.writeln(usage);
      return 64; // EX_USAGE
    }

    final targetDir = rest.isEmpty ? Directory.current : Directory(rest.first);
    if (!targetDir.existsSync()) {
      stderr.writeln('Target directory does not exist: ${targetDir.path}');
      return 66; // EX_NOINPUT
    }

    final dialectDir = Directory(p.join(targetDir.path, 'dialect'));
    final scaffoldExists = dialectDir.existsSync();

    if (scaffoldExists && !force) {
      // Idempotent re-run: refresh the plan + AGENTS.md, leave scaffold alone.
      stdout.writeln(
        '✓ dialect/ scaffold already exists in ${targetDir.path} — '
        'refreshing init plan only (use --force to rewrite scaffold).',
      );
    } else {
      _writeScaffold(dialectDir);
      _printScaffoldSummary();
    }

    final projectType = _detectProjectType(targetDir);
    final projectName = _projectName(targetDir);

    final initPlanPath = _writeInitPlan(
      targetDir: targetDir,
      projectName: projectName,
      projectType: projectType,
    );
    stdout.writeln('  .dialect/init-plan.md');

    final agentsOutcome = _writeAgentsSection(targetDir);
    stdout.writeln('  ${agentsOutcome.relPath} (${agentsOutcome.verb})');

    final gitignoreUpdated = _ensureGitignore(targetDir);
    if (gitignoreUpdated) {
      stdout.writeln('  .gitignore (added .dialect/)');
    }

    if (projectType == 'Flutter') {
      final added = _ensureFlutterGenerateFlag(targetDir);
      if (added) {
        stdout.writeln('  pubspec.yaml (added `flutter: generate: true`)');
      }
      final sourceLocale = _readSourceLocale(targetDir) ?? 'en';
      final arbDir = _readFlutterOutputDir(targetDir);
      if (_ensureL10nYaml(targetDir, sourceLocale, arbDir)) {
        stdout.writeln('  l10n.yaml (gen-l10n config)');
      }
      if (_seedTemplateArb(targetDir, sourceLocale, arbDir)) {
        stdout.writeln(
          '  $arbDir/app_$sourceLocale.arb '
          '(seed — keeps `flutter pub get` green before the first sync)',
        );
      }
    }

    stdout.writeln('');
    stdout.writeln('Detected project type: $projectType');
    stdout.writeln('Init plan written to: $initPlanPath');
    stdout.writeln('');
    stdout.writeln(
      'Next: paste this in your AI agent (Claude Code, Cursor, …):',
    );
    stdout.writeln('');
    stdout.writeln('  run dialect init and follow the instructions');
    stdout.writeln('');
    stdout.writeln(
      'Your agent will execute .dialect/init-plan.md and walk you through '
      'localizing the app.',
    );

    return 0;
  }

  // ---- scaffold ----------------------------------------------------------

  void _writeScaffold(Directory dialectDir) {
    Directory(p.join(dialectDir.path, 'source')).createSync(recursive: true);
    Directory(
      p.join(dialectDir.path, 'translations'),
    ).createSync(recursive: true);

    // Stamp the version we ran as into `toolchain.min_version`, so the
    // project's floor is a fact the CLI recorded rather than a comment
    // someone hand-copied (and later contradicted).
    File(p.join(dialectDir.path, 'dialect.yaml')).writeAsStringSync(
      renderPlanTemplate(dialectYamlTemplate, {
        'DIALECT_VERSION': _minVersionFloor(dialectVersion),
      }),
    );
    File(
      p.join(dialectDir.path, 'glossary.yaml'),
    ).writeAsStringSync(glossaryYamlTemplate);
    File(
      p.join(dialectDir.path, 'source', 'en.arb'),
    ).writeAsStringSync(sourceArbTemplate);
  }

  void _printScaffoldSummary() {
    stdout.writeln('✓ Scaffolded dialect/');
    stdout.writeln('  dialect/dialect.yaml');
    stdout.writeln('  dialect/glossary.yaml');
    stdout.writeln('  dialect/source/en.arb');
    stdout.writeln('  dialect/translations/  (empty)');
  }

  // ---- init plan ---------------------------------------------------------

  /// Render and write `.dialect/init-plan.md`. Always overwrites so a
  /// re-run after `dialect.yaml` edits picks up the fresh values.
  String _writeInitPlan({
    required Directory targetDir,
    required String projectName,
    required String projectType,
  }) {
    final hidden = Directory(p.join(targetDir.path, '.dialect'));
    hidden.createSync(recursive: true);

    final tokens = <String, String>{
      'PROJECT_NAME': projectName,
      'PROJECT_TYPE': projectType,
      'SOURCE_LOCALE': _readSourceLocale(targetDir) ?? 'en',
      'TARGET_LOCALES': _readTargetLocales(targetDir),
      'PUBSPEC_NAME': _readPubspecName(targetDir) ?? '<your_pubspec_name>',
      'GENERATED_AT': DateTime.now().toUtc().toIso8601String(),
    };
    final body = renderPlanTemplate(initPlanMdTemplate, tokens);

    final file = File(p.join(hidden.path, 'init-plan.md'));
    file.writeAsStringSync(body);
    return p.relative(file.path, from: targetDir.path);
  }

  // ---- AGENTS.md ---------------------------------------------------------

  /// Write the Dialect section into `AGENTS.md` (or `CLAUDE.md` if that's
  /// the only one present). Append if the file exists and lacks the
  /// section; create otherwise.
  _AgentsOutcome _writeAgentsSection(Directory targetDir) {
    final agents = File(p.join(targetDir.path, 'AGENTS.md'));
    final claude = File(p.join(targetDir.path, 'CLAUDE.md'));

    File target;
    if (agents.existsSync()) {
      target = agents;
    } else if (claude.existsSync()) {
      // Respect the existing convention — don't create a sibling AGENTS.md
      // when the project already has a CLAUDE.md.
      target = claude;
    } else {
      target = agents;
    }

    final relPath = p.relative(target.path, from: targetDir.path);
    final sourceLocale = _readSourceLocale(targetDir) ?? 'en';
    final body = renderPlanTemplate(agentsMdSection, {
      'SOURCE_LOCALE': sourceLocale,
    });

    if (!target.existsSync()) {
      target.writeAsStringSync(body);
      return _AgentsOutcome(relPath: relPath, verb: 'created');
    }

    final existing = target.readAsStringSync();
    if (existing.contains('## Localization (Dialect)')) {
      // Don't duplicate the section. Could later refresh it; for now,
      // leave it alone so we don't clobber user edits.
      return _AgentsOutcome(relPath: relPath, verb: 'already up to date');
    }

    final separator = existing.endsWith('\n') ? '\n' : '\n\n';
    target.writeAsStringSync('$existing$separator$body', flush: true);
    return _AgentsOutcome(relPath: relPath, verb: 'appended Dialect section');
  }

  // ---- project metadata --------------------------------------------------

  /// Detect what kind of project the target dir is. For v1.0 only Flutter
  /// has a fleshed-out plan template; the rest are best-effort labels for
  /// the report.
  String _detectProjectType(Directory targetDir) {
    if (File(p.join(targetDir.path, 'pubspec.yaml')).existsSync()) {
      return 'Flutter';
    }
    final pkg = File(p.join(targetDir.path, 'package.json'));
    if (pkg.existsSync()) return 'Node';
    if (Directory(
      targetDir.path,
    ).listSync().any((e) => e.path.endsWith('.csproj'))) {
      return 'ASP.NET';
    }
    return 'Unknown';
  }

  /// Best-effort project name. Today we just look at the dir basename;
  /// the AI fills in the rest by reading `dialect.yaml` itself.
  String _projectName(Directory targetDir) {
    final base = p.basename(targetDir.absolute.path);
    return base.isEmpty ? 'Your project' : base;
  }

  /// Read `source_locale:` straight out of `dialect/dialect.yaml` if it
  /// exists. We do this with a simple regex rather than pulling in the
  /// YAML loader to avoid an init-time dependency on a fully-loadable
  /// config (the user may not have edited it yet).
  String? _readSourceLocale(Directory targetDir) {
    final file = File(p.join(targetDir.path, 'dialect', 'dialect.yaml'));
    if (!file.existsSync()) return null;
    final match = RegExp(
      r'^source_locale:\s*(\S+)',
      multiLine: true,
    ).firstMatch(file.readAsStringSync());
    return match?.group(1);
  }

  /// Read `target_locales:` as a comma-joined display string. Returns
  /// a "(none configured yet)" placeholder when the list is empty so
  /// the rendered plan flags the missing config.
  String _readTargetLocales(Directory targetDir) {
    final file = File(p.join(targetDir.path, 'dialect', 'dialect.yaml'));
    if (!file.existsSync()) return '(none configured yet)';
    final match = RegExp(
      r'^target_locales:\s*\[([^\]]*)\]',
      multiLine: true,
    ).firstMatch(file.readAsStringSync());
    if (match == null) return '(none configured yet)';
    final raw = match.group(1)!.trim();
    if (raw.isEmpty) return '(none configured yet)';
    return raw
        .split(',')
        .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  /// Read `name:` from `pubspec.yaml`. Used to spell the AppLocalizations
  /// import correctly under modern Flutter's `synthetic-package: false`
  /// default. Returns null when no pubspec exists (non-Flutter projects).
  String? _readPubspecName(Directory targetDir) {
    final file = File(p.join(targetDir.path, 'pubspec.yaml'));
    if (!file.existsSync()) return null;
    final match = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(file.readAsStringSync());
    return match?.group(1);
  }

  // ---- pubspec.yaml mutation -------------------------------------------

  /// `flutter gen-l10n` refuses to run without `flutter: generate: true`
  /// in pubspec.yaml. The plan template can mention it, but missing the
  /// flag is the kind of opaque blocker that derails the first run, so
  /// init writes it directly. Returns true if the file was modified.
  ///
  /// We skip when `generate:` already appears under any indented context
  /// (the user may have explicitly set `false` and we don't second-guess
  /// that). We insert the flag as the first child of `flutter:` so it
  /// sits next to existing siblings like `uses-material-design`.
  bool _ensureFlutterGenerateFlag(Directory targetDir) {
    final file = File(p.join(targetDir.path, 'pubspec.yaml'));
    if (!file.existsSync()) return false;
    final existing = file.readAsStringSync();
    if (RegExp(r'^\s+generate:\s', multiLine: true).hasMatch(existing)) {
      return false;
    }
    final lines = existing.split('\n');
    for (var i = 0; i < lines.length; i++) {
      // Top-level `flutter:` block opener — may have a trailing comment.
      if (RegExp(r'^flutter:\s*(#.*)?$').hasMatch(lines[i])) {
        lines.insert(i + 1, '  generate: true');
        file.writeAsStringSync(lines.join('\n'));
        return true;
      }
    }
    return false;
  }

  /// The floor to stamp for a binary reporting [version].
  ///
  /// Pre-release suffixes are dropped: a `1.2.0-dev` build stamps `1.2.0`.
  /// Stamping `1.2.0-dev` verbatim would pin every consumer to a build that
  /// only exists between releases; the floor the project actually depends on
  /// is the release those features ship in.
  static String _minVersionFloor(String version) =>
      version.trim().split(RegExp(r'[-+]')).first;

  // ---- gen-l10n wiring ---------------------------------------------------

  /// The Flutter platform's `output:` directory from `dialect.yaml`, without
  /// a trailing slash. This is where `dialect sync` writes, and therefore
  /// what `l10n.yaml`'s `arb-dir` must point at — reading it keeps the two
  /// in agreement instead of hardcoding the default in two places.
  String _readFlutterOutputDir(Directory targetDir) {
    const fallback = 'lib/l10n';
    final file = File(p.join(targetDir.path, 'dialect', 'dialect.yaml'));
    if (!file.existsSync()) return fallback;
    // Match `output:` nested under the `flutter:` platform block, stopping
    // at the next platform (a line indented by two spaces or less).
    final match = RegExp(
      r'^  flutter:\s*$(?:\n(?:[ ]{4,}.*)?$)*?\n[ ]{4}output:[ ]*(\S+)',
      multiLine: true,
    ).firstMatch(file.readAsStringSync());
    final raw = match?.group(1);
    if (raw == null || raw.isEmpty) return fallback;
    final trimmed = raw.replaceAll(RegExp(r'/+$'), '');
    return trimmed.isEmpty ? fallback : trimmed;
  }

  /// Write `l10n.yaml` if the project has none.
  ///
  /// `init` already writes `flutter: generate: true`; without the matching
  /// `l10n.yaml` that flag makes `flutter pub get` *fail* rather than no-op.
  /// Owning one half of the wiring and delegating the other put the very
  /// next command a developer runs into an error state, so init owns both.
  /// An existing file is never touched — the project may point gen-l10n
  /// somewhere deliberate.
  bool _ensureL10nYaml(
    Directory targetDir,
    String sourceLocale,
    String arbDir,
  ) {
    final file = File(p.join(targetDir.path, 'l10n.yaml'));
    if (file.existsSync()) return false;
    file.writeAsStringSync(
      'arb-dir: $arbDir\n'
      'template-arb-file: app_$sourceLocale.arb\n'
      'output-localization-file: app_localizations.dart\n',
    );
    return true;
  }

  /// Seed the generated template ARB so `flutter pub get` succeeds from
  /// minute one.
  ///
  /// `arb-dir` must exist before gen-l10n will run, but the directory is
  /// normally created by the first `dialect sync` — which can't happen until
  /// real keys exist. That left a window where every `pub get` failed with
  /// "The 'arb-dir' directory ... does not exist", an error that names
  /// neither `dialect sync` nor the actual fix. Seeding the same
  /// `commonExample` entry the source scaffold carries closes the window;
  /// the first `sync` simply overwrites this file.
  bool _seedTemplateArb(
    Directory targetDir,
    String sourceLocale,
    String arbDir,
  ) {
    final file = File(p.join(targetDir.path, arbDir, 'app_$sourceLocale.arb'));
    if (file.existsSync()) return false;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      sourceLocale == 'en'
          ? sourceArbTemplate
          : sourceArbTemplate.replaceFirst(
              '"@@locale": "en"',
              '"@@locale": "$sourceLocale"',
            ),
    );
    return true;
  }

  // ---- .gitignore --------------------------------------------------------

  bool _ensureGitignore(Directory targetDir) {
    final file = File(p.join(targetDir.path, '.gitignore'));
    if (!file.existsSync()) {
      file.writeAsStringSync(gitignoreSnippet);
      return true;
    }

    final existing = file.readAsStringSync();
    final alreadyIgnored = existing
        .split('\n')
        .map((l) => l.trim())
        .any((l) => l == '.dialect/' || l == '.dialect');
    if (alreadyIgnored) return false;

    final separator = existing.endsWith('\n') ? '\n' : '\n\n';
    file.writeAsStringSync('$existing$separator$gitignoreSnippet', flush: true);
    return true;
  }
}

class _AgentsOutcome {
  _AgentsOutcome({required this.relPath, required this.verb});
  final String relPath;
  final String verb;
}
