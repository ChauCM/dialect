import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Read/write `.dialect/state.json` — the soft-mode acknowledgement store
/// specified in `dialect/spec/state.md`.
///
/// The file records per-issue acknowledgements keyed by
/// `<rule>:<locale>:<key>`, each fingerprinted with the source/translation
/// value at ack-time. When the value later changes the fingerprint
/// mismatches and the warning re-surfaces. `.dialect/` is gitignored by the
/// canonical `dialect init`, so these acks are workspace-local by design.
///
/// The store is forward-compatible: unknown top-level fields and unknown
/// fields inside an ack record are preserved verbatim on write.
class StateStore {
  StateStore({
    this.version = 1,
    Map<String, AckRecord>? checks,
    Map<String, Object?>? extras,
  }) : checks = checks ?? {},
       extras = extras ?? {};

  /// Wire version. `1` in v1.0; bumps only on a breaking shape change.
  int version;

  /// Acknowledgements keyed by `<rule>:<locale>:<key>`.
  final Map<String, AckRecord> checks;

  /// Unknown top-level fields, preserved verbatim for forward-compat.
  final Map<String, Object?> extras;

  /// Load the store for the project at [root]. A missing file yields an
  /// empty store (not an error). Throws [FormatException] if the file is
  /// present but malformed.
  static StateStore load(String root) {
    final file = File(p.join(root, '.dialect', 'state.json'));
    if (!file.existsSync()) return StateStore();
    return parse(file.readAsStringSync());
  }

  static StateStore parse(String content) {
    final Object? root;
    try {
      root = jsonDecode(content);
    } on FormatException catch (e) {
      throw FormatException(
        '.dialect/state.json is not valid JSON: ${e.message}',
      );
    }
    if (root is! Map<String, Object?>) {
      throw const FormatException('.dialect/state.json must be a JSON object.');
    }

    final version = root['version'];
    final checks = <String, AckRecord>{};
    final rawChecks = root['checks'];
    if (rawChecks is Map<String, Object?>) {
      for (final entry in rawChecks.entries) {
        final v = entry.value;
        if (v is Map<String, Object?>) {
          checks[entry.key] = AckRecord.fromJson(v);
        }
      }
    }

    final extras = <String, Object?>{};
    for (final entry in root.entries) {
      if (entry.key == 'version' || entry.key == 'checks') continue;
      extras[entry.key] = entry.value;
    }

    return StateStore(
      version: version is int ? version : 1,
      checks: checks,
      extras: extras,
    );
  }

  /// Write the store under [root]/.dialect/state.json, creating the
  /// directory if needed. Canonical form: version first, then remaining
  /// top-level keys sorted, `checks` keys sorted, 2-space indent, trailing
  /// newline.
  void save(String root) {
    final file = File(p.join(root, '.dialect', 'state.json'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(encode());
  }

  String encode() {
    // Insertion order is preserved by Dart maps and respected by
    // JsonEncoder, so build the map in the exact output order.
    final out = <String, Object?>{'version': version};
    final extraKeys = extras.keys.toList()..sort();
    for (final k in extraKeys) {
      out[k] = extras[k];
    }
    final sortedCheckKeys = checks.keys.toList()..sort();
    out['checks'] = {for (final k in sortedCheckKeys) k: checks[k]!.toJson()};
    return '${const JsonEncoder.withIndent('  ').convert(out)}\n';
  }
}

/// One acknowledgement record. `acknowledged` is the source/translation
/// fingerprint at ack-time (sha256-16). The rest is informational.
class AckRecord {
  AckRecord({
    required this.acknowledged,
    this.acknowledgedAt,
    this.note,
    this.acknowledgedBy,
    Map<String, Object?>? extras,
  }) : extras = extras ?? {};

  final String acknowledged;
  final String? acknowledgedAt;
  final String? note;
  final String? acknowledgedBy;

  /// Unknown fields inside the record, preserved verbatim.
  final Map<String, Object?> extras;

  static AckRecord fromJson(Map<String, Object?> json) {
    final extras = <String, Object?>{};
    for (final e in json.entries) {
      if (e.key == 'acknowledged' ||
          e.key == 'acknowledged_at' ||
          e.key == 'note' ||
          e.key == 'acknowledged_by') {
        continue;
      }
      extras[e.key] = e.value;
    }
    return AckRecord(
      acknowledged: json['acknowledged'] is String
          ? json['acknowledged'] as String
          : '',
      acknowledgedAt: json['acknowledged_at'] as String?,
      note: json['note'] as String?,
      acknowledgedBy: json['acknowledged_by'] as String?,
      extras: extras,
    );
  }

  Map<String, Object?> toJson() {
    final out = <String, Object?>{'acknowledged': acknowledged};
    if (acknowledgedAt != null) out['acknowledged_at'] = acknowledgedAt;
    if (note != null) out['note'] = note;
    if (acknowledgedBy != null) out['acknowledged_by'] = acknowledgedBy;
    final extraKeys = extras.keys.toList()..sort();
    for (final k in extraKeys) {
      out[k] = extras[k];
    }
    return out;
  }
}
