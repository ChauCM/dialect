/// Typed loader for `dialect/glossary.yaml` — the project's copy policy.
///
/// The file carries two enforced blocks and one advisory one:
///   - `terms:`  — always say this ([GlossaryTerm], enforced by the
///     `glossary` rule).
///   - `banned:` — never say this ([BannedPattern], enforced by the
///     `banned_pattern` rule).
///   - `style:`  — tone and formality, read by a human or an AI translator
///     rather than by a rule, so it is not parsed here.
///
/// `terms` and `banned` are mirror images of one question a reviewer asks
/// about wording, which is why they share a file and a diff rather than
/// living one here and one in `dialect.yaml`. `dialect.yaml` is plumbing:
/// locales, platforms, publish targets.
///
/// The on-disk shape is documented in `templates/glossary.yaml`. Missing
/// file ⇒ empty glossary; malformed YAML ⇒ [FormatException] propagated to
/// the caller (caught by `dialect check` and turned into exit 65).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;

/// One glossary entry: a canonical English `term`, a `meaning` blurb,
/// and `translations` keyed by locale.
class GlossaryTerm {
  GlossaryTerm({
    required this.term,
    required this.meaning,
    required this.translations,
  });

  /// Canonical source-locale form, e.g. `"Book"`. Used for the
  /// whole-word match against source ARB values.
  final String term;

  /// Human-readable meaning. Not consumed by any check rule; the
  /// glossary check passes it along in the issue hint so the user
  /// sees the same disambiguation an AI would.
  final String meaning;

  /// Canonical translation per locale.
  final Map<String, String> translations;
}

/// One `banned:` entry: copy this project does not ship, plus the reason a
/// reviewer should read when it fires.
///
/// The motivating case is punctuation policy — a project that has ruled out
/// em-dashes in user-facing copy — but the mechanism is general: any literal
/// or regular expression that should never reach a screen.
///
/// Two kinds of exception, because real projects have both:
///   - **This one use is right.** `dialect check --ack banned_pattern:…`
///     fingerprints the value it excused, so editing the copy retires the
///     waiver by itself.
///   - **These keys are ruled exempt, permanently.** [except] names them.
///     A ruling survives a typo fix, so it must not expire when the value
///     changes the way an ack does.
///
/// A permanent list is the thing that rots, so `banned_pattern` audits its
/// own: a key in [except] whose value no longer contains the pattern is
/// reported, and the list can only shrink.
class BannedPattern {
  BannedPattern({
    required this.pattern,
    required this.reason,
    this.isRegex = false,
    this.locales = const [],
    this.except = const [],
  });

  /// The literal text (default) or regular expression (`regex: true`) that
  /// must not appear in a value.
  final String pattern;

  /// Why it is banned, and what to write instead. Shown verbatim as the
  /// issue hint, so it should read as advice, not as a restatement of the
  /// pattern.
  final String reason;

  /// Whether [pattern] is a regular expression. Literal is the default so a
  /// pattern full of punctuation needs no escaping.
  final bool isRegex;

  /// Locales this applies to. Empty means every locale, including the
  /// source. `[en]` scopes a rule about English phrasing to English.
  final List<String> locales;

  /// Keys ruled exempt from this pattern for good — a standing decision, not
  /// a one-off waiver. Audited: see [BannedPattern].
  final List<String> except;

  /// Whether [key] is permanently exempt from this pattern.
  bool excuses(String key) => except.contains(key);

  /// Whether this pattern is enforced in [locale], where the source locale
  /// is named by its own tag (a ban on em-dashes applies to the English
  /// source as much as to any translation).
  bool appliesTo(String locale) => locales.isEmpty || locales.contains(locale);

  /// Compiled matcher. Case-insensitive: a banned word is banned however it
  /// is capitalized, and for punctuation the flag is inert.
  late final RegExp _matcher = RegExp(
    isRegex ? pattern : RegExp.escape(pattern),
    caseSensitive: false,
  );

  /// The first occurrence of this pattern in [value], or `null`. Returning
  /// the matched text (rather than a bool) lets the issue quote what it
  /// actually found, which matters when the pattern is a regex.
  String? firstMatch(String value) => _matcher.firstMatch(value)?.group(0);
}

class Glossary {
  Glossary({this.terms = const [], this.banned = const []});

  /// Empty glossary — what callers get when `glossary.yaml` is absent or
  /// declares neither block. Lets rules iterate without null-checks.
  factory Glossary.empty() => Glossary();

  final List<GlossaryTerm> terms;

  /// Parsed `banned:` entries. Empty when the block is absent, in which
  /// case the `banned_pattern` rule no-ops.
  final List<BannedPattern> banned;

  /// Parse a glossary YAML string. Returns an empty [Glossary] when both
  /// the `terms:` and `banned:` blocks are missing or empty. Each block
  /// stands on its own — a file that bans patterns without defining a single
  /// term is valid.
  static Glossary parse(String content) {
    final root = yaml.loadYaml(content);
    if (root == null) return Glossary.empty();
    if (root is! yaml.YamlMap) {
      throw const FormatException(
        'glossary.yaml must be a YAML map at the top level.',
      );
    }
    return Glossary(
      terms: _parseTerms(root['terms']),
      banned: _parseBanned(root['banned']),
    );
  }

  static List<GlossaryTerm> _parseTerms(Object? rawTerms) {
    if (rawTerms == null) return const [];
    if (rawTerms is! yaml.YamlList) {
      throw FormatException(
        'glossary.yaml: `terms:` must be a list, got ${rawTerms.runtimeType}.',
      );
    }
    final terms = <GlossaryTerm>[];
    for (final raw in rawTerms) {
      if (raw is! yaml.YamlMap) {
        throw FormatException(
          'glossary.yaml: each entry under `terms:` must be a map, got '
          '${raw.runtimeType}.',
        );
      }
      final term = raw['term'];
      if (term is! String || term.isEmpty) {
        throw const FormatException(
          'glossary.yaml: each term must have a non-empty `term:` field.',
        );
      }
      final meaning = raw['meaning'];
      final translationsRaw = raw['translations'];
      final translations = <String, String>{};
      if (translationsRaw is yaml.YamlMap) {
        for (final entry in translationsRaw.entries) {
          final k = entry.key;
          final v = entry.value;
          if (k is String && v is String && v.isNotEmpty) {
            translations[k] = v;
          }
        }
      }
      terms.add(
        GlossaryTerm(
          term: term,
          meaning: meaning is String ? meaning.trim() : '',
          translations: translations,
        ),
      );
    }
    return terms;
  }

  /// Parse the `banned:` block. A `reason:` is required — an issue that says
  /// only "this is banned" leaves the reader to guess what to write instead,
  /// and the reason is the whole value of the hint.
  static List<BannedPattern> _parseBanned(Object? rawBanned) {
    if (rawBanned == null) return const [];
    if (rawBanned is! yaml.YamlList) {
      throw FormatException(
        'glossary.yaml: `banned:` must be a list, got '
        '${rawBanned.runtimeType}.',
      );
    }
    final banned = <BannedPattern>[];
    for (final raw in rawBanned) {
      if (raw is! yaml.YamlMap) {
        throw FormatException(
          'glossary.yaml: each entry under `banned:` must be a map, got '
          '${raw.runtimeType}.',
        );
      }
      final pattern = raw['pattern'];
      if (pattern is! String || pattern.isEmpty) {
        throw const FormatException(
          'glossary.yaml: each banned entry must have a non-empty '
          '`pattern:` field.',
        );
      }
      final reason = raw['reason'];
      if (reason is! String || reason.trim().isEmpty) {
        throw FormatException(
          'glossary.yaml: banned entry `$pattern` needs a `reason:` — it is '
          'what the check tells the author to do instead.',
        );
      }
      final isRegex = raw['regex'] == true;
      if (isRegex) {
        try {
          RegExp(pattern);
        } on FormatException catch (e) {
          throw FormatException(
            'glossary.yaml: banned entry `$pattern` is marked `regex: true` '
            'but does not compile: ${e.message}',
          );
        }
      }
      banned.add(
        BannedPattern(
          pattern: pattern,
          reason: reason.trim(),
          isRegex: isRegex,
          locales: _stringList(raw['locales'], pattern, 'locales'),
          except: _stringList(raw['except'], pattern, 'except'),
        ),
      );
    }
    return banned;
  }

  /// Read an optional list-of-strings field on a banned entry, naming the
  /// entry and the field when it is the wrong shape.
  static List<String> _stringList(Object? raw, String pattern, String field) {
    if (raw == null) return const [];
    if (raw is! yaml.YamlList) {
      throw FormatException(
        'glossary.yaml: banned entry `$pattern` has a `$field:` field that '
        'is not a list of strings.',
      );
    }
    return [
      for (final v in raw)
        if (v is String && v.isNotEmpty) v,
    ];
  }

  /// Load `<root>/dialect/glossary.yaml`. Returns an empty glossary
  /// when the file is absent (a fresh `dialect init` without a
  /// glossary is valid — the rule just no-ops).
  static Glossary loadFromProjectRoot(String root) {
    final f = File(p.join(root, 'dialect', 'glossary.yaml'));
    if (!f.existsSync()) return Glossary.empty();
    return parse(f.readAsStringSync());
  }
}
