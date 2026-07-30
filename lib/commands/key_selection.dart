import '../project/dialect_project.dart';

/// Which keys, in which locales, a per-key command should act on.
///
/// `lock` and `accept` are the same gesture pointed at different metadata —
/// "a human reviewed this" — and they had the same limitation: one key per
/// invocation. That is the wrong unit for the motivating case. Locked copy is
/// copy a person deliberately wrote, and a person writes a *body* of it: a
/// page, a screen, a namespace. Blessing one About page cost a 13-iteration
/// shell loop.
///
/// So the subject is now variadic, and `--namespace` names the group Dialect
/// already models.
///
/// `--prefix webAbout` was considered and rejected: a prefix only groups keys
/// when someone happened to name them consistently, while a namespace is the
/// grouping the source ARB actually declares and the one sync already routes
/// on. Two selectors for one idea, where the weaker one silently depends on
/// naming discipline, is a worse surface than one.
class KeySelection {
  KeySelection({required this.keys, required this.locales});

  /// Source keys to act on, sorted and de-duplicated.
  final List<String> keys;

  /// Target locales to act in.
  final List<String> locales;
}

/// A selection that could not be resolved: [code] is the exit code the command
/// should return, [lines] the message to print to stderr.
class SelectionFailure implements Exception {
  SelectionFailure(this.code, this.lines);
  final int code;
  final List<String> lines;
}

/// Resolve [positionals] + [namespace] + [locale] into a [KeySelection]
/// against [project]. Throws [SelectionFailure] with a ready-to-print message
/// when the request cannot be honoured.
///
/// Every positional is a key. Locale selection is `--locale`, because a
/// variadic subject cannot also carry an optional trailing locale without
/// guessing which one a bare `vi` is meant to be. Callers that pass a locale
/// name positionally get told exactly that rather than "no such key".
KeySelection resolveSelection({
  required DialectProject project,
  required String command,
  required List<String> positionals,
  String? namespace,
  String? locale,
}) {
  final targets = project.translations.keys.toList();

  if (locale != null && !project.translations.containsKey(locale)) {
    throw SelectionFailure(64, [
      'Locale `$locale` is not a configured target locale. '
          'Targets: ${targets.join(', ')}.',
    ]);
  }

  final selected = <String>{};

  if (namespace != null) {
    final inNamespace = [
      for (final e in project.source.entries)
        if (e.metadata?.namespace == namespace) e.key,
    ];
    if (inNamespace.isEmpty) {
      final known = {
        for (final e in project.source.entries)
          if (e.metadata?.namespace != null) e.metadata!.namespace!,
      }.toList()..sort();
      throw SelectionFailure(65, [
        'No source key declares `namespace: $namespace`.',
        known.isEmpty
            ? '  This source has no namespaced keys yet.'
            : '  Namespaces in this source: ${known.join(', ')}.',
      ]);
    }
    selected.addAll(inNamespace);
  }

  final unknown = <String>[];
  for (final key in positionals) {
    if (project.source.entryFor(key) == null) {
      unknown.add(key);
    } else {
      selected.add(key);
    }
  }

  if (unknown.isNotEmpty) {
    final lines = <String>[
      unknown.length == 1
          ? 'Key `${unknown.first}` is not in the source ARB — nothing to '
                '$command against. Add it to dialect/source first.'
          : '${unknown.length} keys are not in the source ARB: '
                '${unknown.join(', ')}. Add them to dialect/source first.',
    ];
    // The one migration everybody will hit: `dialect lock brand vi` used to
    // mean "vi only", and now reads as a second key.
    final asLocale = unknown.where(targets.contains).toList();
    if (asLocale.isNotEmpty) {
      lines.add(
        '  `${asLocale.first}` is a locale, not a key — $command takes any '
        'number of keys now, so locale selection moved to '
        '`--locale ${asLocale.first}`.',
      );
    }
    throw SelectionFailure(65, lines);
  }

  if (selected.isEmpty) {
    throw SelectionFailure(64, [
      '$command takes one or more <key>s, or --namespace <name>.',
      '  e.g. dialect $command brandTagline',
      '       dialect $command webAboutTitle webAboutBody --locale vi',
      '       dialect $command --namespace web',
    ]);
  }

  return KeySelection(
    keys: selected.toList()..sort(),
    locales: locale != null ? [locale] : targets,
  );
}

/// `key` / `N keys`, for a summary line that reads the same either way.
String describeKeyCount(int n) => n == 1 ? '1 key' : '$n keys';

/// A short, sorted preview of [keys] for a summary line.
String previewKeys(Iterable<String> keys, {int limit = 6}) {
  final sorted = keys.toList()..sort();
  if (sorted.length <= limit) return sorted.join(', ');
  return '${sorted.take(limit).join(', ')}, … (${sorted.length - limit} more)';
}
