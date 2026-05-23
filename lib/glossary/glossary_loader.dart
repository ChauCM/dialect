/// Typed loader for `dialect/glossary.yaml`.
///
/// The on-disk shape is documented in `templates/glossary.yaml`. The
/// glossary rule (`lib/checks/semantic/glossary.dart`) consumes the
/// parsed form. Missing file ⇒ empty glossary; malformed YAML ⇒
/// [FormatException] propagated to the caller (caught by
/// `dialect check` and turned into exit 65).
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

class Glossary {
  Glossary({this.terms = const []});

  /// Empty glossary — what callers get when `glossary.yaml` is absent
  /// or has no `terms:` block. Lets rules iterate without null-checks.
  factory Glossary.empty() => Glossary();

  final List<GlossaryTerm> terms;

  /// Parse a glossary YAML string. Returns an empty [Glossary] when the
  /// `terms:` block is missing or empty.
  static Glossary parse(String content) {
    final root = yaml.loadYaml(content);
    if (root == null) return Glossary.empty();
    if (root is! yaml.YamlMap) {
      throw const FormatException(
        'glossary.yaml must be a YAML map at the top level.',
      );
    }
    final rawTerms = root['terms'];
    if (rawTerms == null) return Glossary.empty();
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
    return Glossary(terms: terms);
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
