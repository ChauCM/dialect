import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'arb_file.dart';

/// Reads ARB JSON into [ArbFile]. All string values are NFC-normalized on
/// read so two visually-identical strings (one composed, one decomposed)
/// hash and compare identically.
///
/// Vietnamese on macOS is the canonical example: native input often
/// produces NFD; without normalization, `dialect check` would fire false
/// stale-key warnings.
class ArbParser {
  const ArbParser._();

  /// Parse ARB content from a UTF-8 string.
  static ArbFile parse(String content) {
    final root = jsonDecode(content);
    if (root is! Map) {
      throw const FormatException('ARB root must be a JSON object.');
    }

    String? locale;
    final fileMetadata = <String, Object?>{};
    final partials = <String, _PartialEntry>{};
    final insertionOrder = <String>[];

    root.forEach((rawKey, value) {
      if (rawKey is! String) {
        throw FormatException(
          'ARB key must be a string, got ${rawKey.runtimeType}.',
        );
      }

      if (rawKey == '@@locale') {
        if (value is! String) {
          throw const FormatException('@@locale must be a string.');
        }
        locale = _nfc(value);
        return;
      }

      if (rawKey.startsWith('@@')) {
        // Other ARB-level metadata (e.g. Flutter gen_l10n's @@last_modified,
        // custom @@x-context). Preserve verbatim so the writer round-trips
        // them — silent stripping would corrupt user data on `dialect sync`.
        fileMetadata[rawKey] = value;
        return;
      }

      if (rawKey.startsWith('@')) {
        final dataKey = rawKey.substring(1);
        final partial = partials.putIfAbsent(
          dataKey,
          () => _PartialEntry(dataKey),
        );
        if (value is! Map) {
          throw FormatException(
            'Metadata for "$dataKey" must be a JSON object, got '
            '${value.runtimeType}.',
          );
        }
        partial.metadata = _parseMetadata(value);
        if (!insertionOrder.contains(dataKey)) insertionOrder.add(dataKey);
        return;
      }

      if (value is! String) {
        throw FormatException(
          'Value for "$rawKey" must be a string, got ${value.runtimeType}.',
        );
      }
      final partial = partials.putIfAbsent(rawKey, () => _PartialEntry(rawKey));
      partial.value = _nfc(value);
      if (!insertionOrder.contains(rawKey)) insertionOrder.add(rawKey);
    });

    if (locale == null) {
      throw const FormatException('ARB file missing @@locale.');
    }

    final entries = <ArbEntry>[];
    final orphans = <String, ArbMetadata>{};
    for (final key in insertionOrder) {
      final p = partials[key]!;
      if (p.value == null) {
        // Metadata-only entry — `@key` block without a corresponding
        // key/value pair. Preserve so `dialect check` (M4) can surface it
        // as a structural error. `dialect check --fix` strips orphans by
        // construction — the writer never emits orphanMetadata.
        if (p.metadata != null) orphans[key] = p.metadata!;
        continue;
      }
      entries.add(ArbEntry(key: key, value: p.value!, metadata: p.metadata));
    }

    return ArbFile(
      locale: locale!,
      entries: entries,
      fileMetadata: fileMetadata,
      orphanMetadata: orphans,
    );
  }

  static ArbMetadata _parseMetadata(Map<dynamic, dynamic> raw) {
    String? description;
    String? context;
    Map<String, ArbPlaceholder>? placeholders;
    var locked = false;
    var glossaryExempt = false;
    String? sourceHash;
    final extras = <String, Object?>{};

    raw.forEach((rawK, v) {
      final k = rawK as String;
      switch (k) {
        case 'description':
          description = v is String ? _nfc(v) : null;
        case 'context':
          context = v is String ? v : null;
        case 'locked':
          locked = v == true;
        case 'glossary_exempt':
          glossaryExempt = v == true;
        case 'source_hash':
          sourceHash = v is String ? v : null;
        case 'placeholders':
          if (v is Map) {
            placeholders = <String, ArbPlaceholder>{};
            v.forEach((pk, pv) {
              if (pk is String && pv is Map) {
                placeholders![pk] = _parsePlaceholder(pv);
              }
            });
          }
        default:
          extras[k] = v;
      }
    });

    return ArbMetadata(
      description: description,
      context: context,
      placeholders: placeholders,
      locked: locked,
      glossaryExempt: glossaryExempt,
      sourceHash: sourceHash,
      extras: extras,
    );
  }

  static ArbPlaceholder _parsePlaceholder(Map<dynamic, dynamic> raw) {
    String? type;
    String? format;
    final extras = <String, Object?>{};
    raw.forEach((rawK, v) {
      final k = rawK as String;
      switch (k) {
        case 'type':
          type = v is String ? v : null;
        case 'format':
          format = v is String ? v : null;
        default:
          extras[k] = v;
      }
    });
    return ArbPlaceholder(type: type, format: format, extras: extras);
  }

  static String _nfc(String s) => unorm.nfc(s);
}

class _PartialEntry {
  _PartialEntry(this.key);
  final String key;
  String? value;
  ArbMetadata? metadata;
}
