import '../../project/dialect_project.dart';
import '../rule.dart';

/// ARB keys must be valid Dart identifiers so `flutter gen-l10n` can
/// emit a callable method per key. The convention prescribes flat
/// camelCase (`checkoutBookNow`); this rule rejects anything that
/// breaks the gen-l10n contract.
///
/// Most common failure mode: dotted keys from the pre-1.0 convention
/// (`checkout.bookNow`). The hint walks the user to the right shape.
class KeyFormatRule extends Rule {
  const KeyFormatRule();

  @override
  String get name => 'key_format';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  // Valid Dart identifier: starts with a letter or underscore, then any
  // run of letters/digits/underscores. We deliberately exclude `$`
  // (legal in Dart but conventionally reserved for codegen) and accept
  // ASCII only — non-ASCII identifiers are legal Dart but trip up many
  // editors and `gen-l10n`'s emitted code.
  static final RegExp _validIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  @override
  List<Issue> run(DialectProject project) {
    final issues = <Issue>[];

    for (final entry in project.source.entries) {
      if (_validIdentifier.hasMatch(entry.key)) continue;
      issues.add(
        Issue(
          severity: defaultSeverity,
          ruleName: name,
          message:
              'Key `${entry.key}` is not a valid Dart identifier — '
              '`flutter gen-l10n` will not accept it.',
          key: entry.key,
          file: project.source.sourcePath,
          line: project.source.entryLines[entry.key],
          hint: entry.key.contains('.')
              ? 'Use flat camelCase per the convention: '
                    '`${_suggest(entry.key)}` with '
                    '`"namespace": "${entry.key.split('.').first}"` in '
                    'the `@key` block. Dotted keys break gen-l10n.'
              : 'Rename the key to flat camelCase starting with a letter, '
                    'e.g. `${_suggest(entry.key)}`.',
        ),
      );
    }

    return issues;
  }

  /// Best-effort suggestion: drop everything that isn't `[A-Za-z0-9]`,
  /// then camelCase across former separators. Good enough for the hint —
  /// the user picks the final name.
  static String _suggest(String key) {
    final parts = key.split(RegExp(r'[^A-Za-z0-9]+'));
    if (parts.isEmpty || parts.every((p) => p.isEmpty)) return 'newKey';
    final head = parts.first.isEmpty
        ? 'key'
        : parts.first[0].toLowerCase() + parts.first.substring(1);
    final tail = parts.skip(1).where((p) => p.isNotEmpty).map(
      (p) => p[0].toUpperCase() + p.substring(1),
    );
    return [head, ...tail].join();
  }
}
