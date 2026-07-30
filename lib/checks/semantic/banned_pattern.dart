import '../../arb/arb_file.dart';
import '../../glossary/glossary_loader.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Copy the project has ruled out reaches a value. The patterns come from
/// the `banned:` block of `dialect/glossary.yaml`.
///
/// This is the mirror of the `glossary` rule: a glossary says *always say
/// this*,
/// `banned:` says *never say that*, and both are questions a reviewer asks
/// about wording, so they share a file. The motivating case is punctuation
/// policy — a project that has ruled out em-dashes in user-facing copy — but
/// nothing here is specific to that.
///
/// **It runs on the source too.** A banned pattern is a statement about what
/// ships, and the source locale ships. Scoping to translations would have
/// left the original English, which is the locale most such rules are
/// actually written about, unchecked. Per-entry `locales:` narrows it back
/// down when a rule really is about one language.
///
/// **Severity is warning, and that is the whole design.** A project that
/// wants this as a hard gate runs `dialect check --strict`, the same lever
/// that promotes every other heuristic; a project still cleaning up existing
/// copy gets a list rather than a wall.
///
/// **Two exceptions, because copy policy has two.**
/// `dialect check --ack banned_pattern:LOCALE:KEY` waives one use and expires
/// when that value is edited. `except:` on the pattern names keys ruled exempt
/// for good, which must survive a typo fix. The standing list is the one that
/// can rot, so this rule audits it: an `except:` key that no longer contains
/// the pattern is reported, and the list can only shrink.
class BannedPatternRule extends Rule {
  const BannedPatternRule();

  @override
  String get name => 'banned_pattern';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final banned = project.glossary.banned;
    if (banned.isEmpty) return const [];

    final issues = <Issue>[];
    // Which `except:` keys actually earned their place this run, per pattern.
    final excusedInPractice = <String, Set<String>>{};

    _scan(
      issues: issues,
      excusedInPractice: excusedInPractice,
      banned: banned,
      arb: project.source,
      locale: project.config.sourceLocale,
      // A source-side issue carries no target locale, which is what puts
      // `source` in its ack id (see ackId()).
      reportedLocale: null,
    );

    for (final entry in project.translations.entries) {
      if (entry.key == project.config.sourceLocale) continue;
      _scan(
        issues: issues,
        excusedInPractice: excusedInPractice,
        banned: banned,
        arb: entry.value,
        locale: entry.key,
        reportedLocale: entry.key,
      );
    }

    issues.addAll(_auditExcept(banned, excusedInPractice, project));
    return issues;
  }

  /// Report `except:` entries that no longer excuse anything: the key is gone
  /// from the project, or its copy was rewritten and the pattern is not in it
  /// any more.
  ///
  /// Without this the standing exemption list is exactly the artefact it was
  /// meant to replace — a hand-maintained list that quietly stops describing
  /// the code. One issue per pattern, so a long list reads as one finding.
  List<Issue> _auditExcept(
    List<BannedPattern> banned,
    Map<String, Set<String>> excusedInPractice,
    DialectProject project,
  ) {
    final issues = <Issue>[];
    for (final pattern in banned) {
      if (pattern.except.isEmpty) continue;
      final earned = excusedInPractice[pattern.pattern] ?? const <String>{};
      final dead = pattern.except.where((k) => !earned.contains(k)).toList()
        ..sort();
      if (dead.isEmpty) continue;

      issues.add(
        Issue(
          severity: defaultSeverity,
          ruleName: name,
          message:
              '${dead.length} key(s) named in the `except:` list for '
              '`${pattern.pattern}` no longer contain it: '
              '${dead.join(', ')}.',
          file: project.source.sourcePath,
          hint:
              'The copy was rewritten or the key was deleted, so the '
              'exemption is excusing nothing. Remove those names from '
              '`except:` in dialect/glossary.yaml — a standing exemption '
              'list is only trustworthy if it can shrink.',
        ),
      );
    }
    return issues;
  }

  void _scan({
    required List<Issue> issues,
    required Map<String, Set<String>> excusedInPractice,
    required List<BannedPattern> banned,
    required ArbFile arb,
    required String locale,
    required String? reportedLocale,
  }) {
    for (final t in arb.entries) {
      for (final pattern in banned) {
        if (!pattern.appliesTo(locale)) continue;
        final hit = pattern.firstMatch(t.value);
        if (hit == null) continue;

        if (pattern.excuses(t.key)) {
          // A live exemption: this key really does still carry the pattern,
          // so its name on the list is earning its place.
          excusedInPractice
              .putIfAbsent(pattern.pattern, () => <String>{})
              .add(t.key);
          continue;
        }

        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message:
                '`${t.key}` in `$locale` contains "$hit", which this '
                'project bans.',
            locale: reportedLocale,
            key: t.key,
            file: arb.sourcePath,
            line: arb.entryLines[t.key],
            hint:
                '${pattern.reason} '
                '(Rule: `${pattern.pattern}`'
                '${pattern.isRegex ? ', a regex' : ''}, from the `banned:` '
                'block of dialect/glossary.yaml.) If this one use is right, '
                'run `dialect check --ack $name:'
                '${reportedLocale ?? 'source'}:${t.key}`.',
          ),
        );
      }
    }
  }
}
