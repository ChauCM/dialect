import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../arb/arb_file.dart';
import '../arb/freshness.dart';
import '../arb/icu_message.dart';
import '../glossary/glossary_loader.dart';
import '../project/dialect_project.dart';
import '../templates/plan_render.dart';
import '../templates/translate_plan_md.dart';

/// `dialect translate` — AI-pointer flow (primary), direct LLM call
/// (`--auto`) as a CI convenience.
///
/// The default path writes `.dialect/translate-plan.md` with a computed
/// work list (which keys are missing per locale, which locked keys went
/// stale) and hands it to the user's AI agent. Dialect never calls an LLM
/// on this path — that's what keeps it model-agnostic and vendor-neutral.
///
/// `--auto` is the escape hatch for CI where no agent is in the loop; it
/// is not yet wired to a provider (see the message below) — the AI-pointer
/// flow is the documented primary path.
class TranslateCommand extends Command<int> {
  TranslateCommand() {
    argParser
      ..addFlag(
        'auto',
        negatable: false,
        help:
            'CI convenience: call an LLM directly instead of writing a plan. '
            'Requires --provider and that provider\'s API key.',
      )
      ..addOption(
        'provider',
        allowed: ['anthropic', 'openai'],
        help:
            'LLM provider for --auto. BYO key — Dialect never resells '
            'inference.',
      );
  }

  @override
  String get name => 'translate';

  @override
  String get description =>
      'Write an AI-pointer plan that translates missing keys (--auto for a '
      'direct LLM call).';

  @override
  String get invocation =>
      'dialect translate [--auto --provider <name>] [project-root]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final auto = results['auto'] as bool;
    final rest = results.rest;

    if (rest.length > 1) {
      stderr.writeln(
        'dialect translate takes at most one positional argument.',
      );
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

    if (auto) {
      // The direct-LLM path is on the roadmap (v1.2) but not built. Fail
      // loudly rather than silently no-op in CI.
      stderr.writeln(
        '--auto is not available yet. The AI-pointer flow is the primary '
        'path: run `dialect translate` (no flags) and have your AI agent '
        'execute the generated plan.',
      );
      return 70;
    }

    if (project.config.targetLocales.isEmpty) {
      stdout.writeln(
        '! dialect translate: no `target_locales` configured in dialect.yaml.',
      );
      stdout.writeln('  Add a target locale and re-run.');
      return 0;
    }

    final work = _computeWork(project);
    final tokens = {
      ...commonPlanTokens(project),
      'WORKLIST': _renderWorklist(work, project),
    };
    final rendered = renderPlanTemplate(translatePlanMdTemplate, tokens);

    final planPath = p.join(root, '.dialect', 'translate-plan.md');
    final planFile = File(planPath);
    planFile.parent.createSync(recursive: true);
    planFile.writeAsStringSync(rendered);

    final relativePath = p.relative(planPath, from: Directory.current.path);
    final totalToTranslate = work.fold<int>(
      0,
      (n, w) => n + w.missing.length + w.staleUnlocked.length,
    );
    final totalStaleLocked = work.fold<int>(
      0,
      (n, w) => n + w.staleLocked.length,
    );

    if (totalToTranslate == 0 && totalStaleLocked == 0) {
      stdout.writeln(
        '✓ dialect translate: every target locale is fully translated and '
        'fresh — nothing to do.',
      );
      stdout.writeln('  (Wrote $relativePath anyway, for the record.)');
      return 0;
    }

    stdout.writeln(
      'Wrote translate plan to $relativePath '
      '($totalToTranslate key(s) to (re)translate'
      '${totalStaleLocked > 0 ? ', $totalStaleLocked stale lock(s) to review' : ''}).',
    );
    stdout.writeln(
      '  Next: open your AI tool (Claude Code, Cursor, Cline, Copilot, …)',
    );
    stdout.writeln('  and ask it to follow the plan:');
    stdout.writeln('    "Read $relativePath and execute the steps."');
    return 0;
  }

  /// Per-locale work buckets: keys missing a translation, unlocked stale
  /// keys (source changed → safe to re-translate), and locked stale keys
  /// (human-approved → review only, never auto-overwritten). Missing keys
  /// are returned in source order so the plan reads top-to-bottom like the
  /// ARB.
  static List<_LocaleWork> _computeWork(DialectProject project) {
    final sourceKeysInOrder = [for (final e in project.source.entries) e.key];
    final sourceHashes = computeSourceHashes(project.source);

    final work = <_LocaleWork>[];
    for (final locale in project.config.targetLocales) {
      final arb = project.translations[locale];
      final translationByKey = {
        if (arb != null)
          for (final e in arb.entries) e.key: e,
      };

      final missing = [
        for (final key in sourceKeysInOrder)
          if (!translationByKey.containsKey(key)) key,
      ];

      final staleUnlocked = <String>[];
      final staleLocked = <String>[];
      for (final entry in translationByKey.values) {
        if (!isStaleEntry(entry, sourceHashes)) continue;
        if (entry.metadata?.locked ?? false) {
          staleLocked.add(entry.key);
        } else {
          staleUnlocked.add(entry.key);
        }
      }
      staleUnlocked.sort();
      staleLocked.sort();

      work.add(
        _LocaleWork(
          locale: locale,
          missing: missing,
          staleUnlocked: staleUnlocked,
          staleLocked: staleLocked,
        ),
      );
    }
    return work;
  }

  /// Render the work list as Markdown for the `{{WORKLIST}}` token. Each
  /// key to translate carries its source string, description, and any
  /// glossary terms detected in the source — inlined so the agent
  /// translates from the meaning, not a bare string, with no second lookup.
  static String _renderWorklist(
    List<_LocaleWork> work,
    DialectProject project,
  ) {
    final hasAnything = work.any((w) => w.hasWork);
    if (!hasAnything) {
      return 'Every target locale is fully translated and nothing has gone '
          'stale. There is nothing to do — you can stop here.';
    }

    final sourceByKey = <String, ArbEntry>{
      for (final e in project.source.entries) e.key: e,
    };

    final buf = StringBuffer();
    for (final w in work) {
      if (!w.hasWork) {
        buf.writeln('### `${w.locale}` — up to date');
        buf.writeln();
        continue;
      }
      buf.writeln('### `${w.locale}`');
      buf.writeln();
      if (w.missing.isNotEmpty) {
        buf.writeln('**Missing (${w.missing.length}) — translate these:**');
        buf.writeln();
        for (final key in w.missing) {
          buf.write(
            _renderKeyEntry(key, w.locale, sourceByKey, project.glossary),
          );
        }
        buf.writeln();
      }
      if (w.staleUnlocked.isNotEmpty) {
        buf.writeln(
          '**Stale (${w.staleUnlocked.length}) — the English source changed; '
          're-translate, then delete each key\'s `@<key>` block so the CLI '
          're-stamps it fresh:**',
        );
        buf.writeln();
        for (final key in w.staleUnlocked) {
          buf.write(
            _renderKeyEntry(key, w.locale, sourceByKey, project.glossary),
          );
        }
        buf.writeln();
      }
      if (w.staleLocked.isNotEmpty) {
        buf.writeln(
          '**Stale (locked) (${w.staleLocked.length}) — review only, do '
          'NOT edit:**',
        );
        buf.writeln();
        for (final key in w.staleLocked) {
          buf.writeln('- `$key`');
        }
        buf.writeln();
      }
    }
    return buf.toString().trimRight();
  }

  /// One worklist bullet with the source value, description/context, and any
  /// glossary terms found in the source (with their target-locale form).
  static String _renderKeyEntry(
    String key,
    String locale,
    Map<String, ArbEntry> sourceByKey,
    Glossary glossary,
  ) {
    final buf = StringBuffer()..writeln('- `$key`');
    final src = sourceByKey[key];
    // The work list is built from source keys, so this is always present;
    // guard anyway rather than emit a half-entry.
    if (src == null) return buf.toString();

    buf.writeln('  - source: ${_inlineValue(src.value)}');
    final description = src.metadata?.description?.trim();
    if (description != null && description.isNotEmpty) {
      buf.writeln('  - description: $description');
    }
    final context = src.metadata?.context?.trim();
    if (context != null && context.isNotEmpty) {
      buf.writeln('  - context: $context');
    }
    final terms = _glossaryTermsIn(src.value, glossary);
    if (terms.isNotEmpty) {
      final rendered = terms
          .map((t) {
            final target = t.translations[locale];
            return target != null ? '${t.term} → $target' : t.term;
          })
          .join('; ');
      buf.writeln('  - glossary: $rendered');
    }
    return buf.toString();
  }

  /// Collapse newlines so a multi-line ICU value stays on one bullet; keep
  /// the ICU structure otherwise verbatim.
  static String _inlineValue(String value) =>
      '"${value.replaceAll('\n', '\\n')}"';

  /// Glossary terms whose canonical English form appears in [source].
  /// Single-word terms match on a word boundary (so "step" doesn't fire
  /// inside "steps"); multi-word terms match as a case-insensitive
  /// substring (the tokenizer can't see across the space).
  static List<GlossaryTerm> _glossaryTermsIn(String source, Glossary glossary) {
    if (glossary.terms.isEmpty) return const [];
    // Scan literal copy only — a term that appears solely as a `{placeholder}`
    // name (e.g. `"Step · {journey}"`) isn't in the copy, so it must not be
    // surfaced as a term to translate. Matches the glossary check (#6).
    final literal = IcuMessage.literalText(source);
    final tokens = _tokenize(literal);
    final lowerSource = literal.toLowerCase();
    final hits = <GlossaryTerm>[];
    for (final term in glossary.terms) {
      final t = term.term.toLowerCase();
      final matched = t.contains(' ')
          ? lowerSource.contains(t)
          : tokens.contains(t);
      if (matched) hits.add(term);
    }
    return hits;
  }

  static Set<String> _tokenize(String value) {
    final out = <String>{};
    final buf = StringBuffer();
    for (final c in value.toLowerCase().codeUnits) {
      final isAlnum = (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39);
      if (isAlnum) {
        buf.writeCharCode(c);
      } else if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }
}

class _LocaleWork {
  _LocaleWork({
    required this.locale,
    required this.missing,
    required this.staleUnlocked,
    required this.staleLocked,
  });
  final String locale;
  final List<String> missing;

  /// Stale and unlocked → re-translate (source changed).
  final List<String> staleUnlocked;

  /// Stale and locked → human-approved; review only, never auto-overwrite.
  final List<String> staleLocked;

  bool get hasWork =>
      missing.isNotEmpty || staleUnlocked.isNotEmpty || staleLocked.isNotEmpty;
}
