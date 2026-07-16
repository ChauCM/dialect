import 'dart:convert';

import 'arb_file.dart';

/// Writes an [ArbFile] to canonical ARB JSON.
///
/// Canonical format, matching `test/fixtures/canonical/dialect/source/en.arb` byte-for-byte:
/// - 2-space indentation.
/// - `@@locale` is always the first entry.
/// - Entries are sorted by key, byte-wise lexicographic ordering (dot is
///   ordinary text).
/// - Each `@key` metadata block appears immediately after its key, no blank
///   line between them.
/// - A blank line separates each (key, @key) group from the next.
/// - Metadata fields appear in this order if present: namespace, description,
///   context, placeholders, locked, glossary_exempt, source_hash, then any
///   extras in alphabetical order.
/// - Trailing newline.
///
/// Same input → same byte-identical output: that's the round-trip property
/// `dialect check --fix` relies on.
class ArbWriter {
  const ArbWriter._();

  static String encode(ArbFile arb) {
    final buf = StringBuffer();
    buf.writeln('{');

    // @@locale always first.
    buf.write('  "@@locale": ');
    buf.write(jsonEncode(arb.locale));

    // Other file-level @@-metadata in sorted order — preserve, do not
    // silently strip user data (e.g. Flutter gen_l10n's @@last_modified).
    final extraFileKeys = arb.fileMetadata.keys.toList()..sort();
    for (final k in extraFileKeys) {
      buf.writeln(',');
      buf.write('  ');
      buf.write(jsonEncode(k));
      buf.write(': ');
      buf.write(jsonEncode(arb.fileMetadata[k]));
    }

    final sorted = [...arb.entries]..sort((a, b) => a.key.compareTo(b.key));

    if (sorted.isEmpty) {
      buf.writeln();
      buf.writeln('}');
      return buf.toString();
    }

    buf.writeln(',');

    for (var i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      final isLast = i == sorted.length - 1;

      // Blank line before each group.
      buf.writeln();

      // Key/value line.
      buf.write('  ');
      buf.write(jsonEncode(entry.key));
      buf.write(': ');
      buf.write(jsonEncode(entry.value));

      if (entry.metadata != null) {
        buf.writeln(',');
        // @key metadata block.
        buf.write('  ');
        buf.write(jsonEncode('@${entry.key}'));
        buf.write(': ');
        _writeMetadata(buf, entry.metadata!);
      }

      if (isLast) {
        buf.writeln();
      } else {
        buf.writeln(',');
      }
    }

    buf.writeln('}');
    return buf.toString();
  }

  static void _writeMetadata(StringBuffer buf, ArbMetadata meta) {
    final lines = <String>[];

    if (meta.namespace != null) {
      lines.add('    "namespace": ${jsonEncode(meta.namespace)}');
    }
    if (meta.description != null) {
      lines.add('    "description": ${jsonEncode(meta.description)}');
    }
    if (meta.context != null) {
      lines.add('    "context": ${jsonEncode(meta.context)}');
    }
    if (meta.placeholders != null && meta.placeholders!.isNotEmpty) {
      lines.add(_placeholdersBlock(meta.placeholders!));
    }
    if (meta.locked) {
      lines.add('    "locked": true');
    }
    if (meta.glossaryExempt) {
      lines.add('    "glossary_exempt": true');
    }
    if (meta.sourceHash != null) {
      lines.add('    "source_hash": ${jsonEncode(meta.sourceHash)}');
    }
    // Extras: alphabetical order, pass through as JSON.
    final extraKeys = meta.extras.keys.toList()..sort();
    for (final k in extraKeys) {
      lines.add('    ${jsonEncode(k)}: ${jsonEncode(meta.extras[k])}');
    }

    if (lines.isEmpty) {
      buf.write('{}');
      return;
    }

    buf.writeln('{');
    for (var i = 0; i < lines.length; i++) {
      buf.write(lines[i]);
      if (i < lines.length - 1) {
        buf.writeln(',');
      } else {
        buf.writeln();
      }
    }
    buf.write('  }');
  }

  static String _placeholdersBlock(Map<String, ArbPlaceholder> placeholders) {
    final buf = StringBuffer();
    buf.writeln('    "placeholders": {');
    // Declaration order, NEVER sorted: Flutter's gen_l10n derives the
    // generated method's parameter order from the order placeholders are
    // declared, so re-sorting here silently changes the generated Dart API
    // and breaks every call site.
    final keys = placeholders.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      final ph = placeholders[k]!;
      buf.write('      ');
      buf.write(jsonEncode(k));
      buf.write(': ');
      buf.write(_inlinePlaceholder(ph));
      if (i < keys.length - 1) {
        buf.writeln(',');
      } else {
        buf.writeln();
      }
    }
    buf.write('    }');
    return buf.toString();
  }

  static String _inlinePlaceholder(ArbPlaceholder ph) {
    final parts = <String>[];
    if (ph.type != null) parts.add('"type": ${jsonEncode(ph.type)}');
    if (ph.format != null) parts.add('"format": ${jsonEncode(ph.format)}');
    final extraKeys = ph.extras.keys.toList()..sort();
    for (final k in extraKeys) {
      parts.add('${jsonEncode(k)}: ${jsonEncode(ph.extras[k])}');
    }
    if (parts.isEmpty) return '{}';
    return '{ ${parts.join(', ')} }';
  }
}
