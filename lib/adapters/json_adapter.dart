import 'dart:convert';

import '../arb/arb_file.dart';
import '../arb/icu_message.dart';

/// Backend JSON adapter — emits the two stable on-disk contracts a backend
/// localizer library reads:
///
/// - **`icu-json`** ([dialect/spec/icu-json.md]) — flat `key → value` JSON
///   with ICU MessageFormat expressions preserved verbatim. For backends
///   with an ICU runtime (`MessageFormat.NET`, `intl-messageformat`, …).
/// - **`flat-json`** ([dialect/spec/flat-json.md]) — same shape, but every
///   plural / select / selectordinal collapses to its `other` branch and
///   typed placeholders drop their format suffix. For backends with no ICU
///   runtime that only do plain `{placeholder}` interpolation.
///
/// Both formats share the file shape: a UTF-8 JSON object, flat string
/// keys (the ARB key verbatim — never nested), 2-space indent, LF endings,
/// trailing newline, keys sorted lexicographically. `@@`-metadata and
/// `@key` blocks are never emitted — the locale is in the filename and
/// metadata is an ARB-side concern.
///
/// Namespace filtering and translation-metadata stripping are handled
/// upstream by [ArbAdapter.prepare]; this adapter only encodes the
/// already-filtered [ArbFile]. That keeps the namespace contract identical
/// across every output format.
class JsonAdapter {
  const JsonAdapter._();

  /// Filename for a backend JSON locale file: `<locale>.json` (e.g.
  /// `en.json`, `pt-BR.json`). Both `icu-json` and `flat-json` use it.
  static String filenameFor(String locale) => '$locale.json';

  /// True for the two formats this adapter handles.
  static bool handles(String format) =>
      format == 'icu-json' || format == 'flat-json';

  /// Encode a (namespace-filtered) [arb] to backend JSON.
  ///
  /// When [stripPlurals] is true the output is `flat-json` — ICU
  /// expressions collapse to their `other` branch. When false the output
  /// is `icu-json` — values pass through verbatim.
  ///
  /// Returns the encoded bytes plus the keys whose ICU was collapsed, so
  /// `dialect sync` can surface the lossy-event hint required by the
  /// `flat-json` spec. For `icu-json` the collapsed list is always empty.
  ///
  /// Throws [FormatException] if a `flat-json` value has a plural / select
  /// expression with no `other` branch.
  static JsonEncodeResult encode(ArbFile arb, {required bool stripPlurals}) {
    final map = <String, String>{};
    final collapsedKeys = <String>[];

    for (final entry in arb.entries) {
      var value = entry.value;
      if (stripPlurals) {
        final hadExpression = IcuMessage.hasPluralOrSelect(value);
        value = IcuMessage.flattenToOther(value, keyHint: entry.key);
        if (hadExpression) collapsedKeys.add(entry.key);
      }
      map[entry.key] = value;
    }

    return JsonEncodeResult(
      content: _encodeFlat(map),
      collapsedKeys: collapsedKeys,
    );
  }

  /// Render [map] as a flat JSON object: sorted keys, 2-space indent, LF
  /// endings, trailing newline. Non-ASCII values are emitted as literal
  /// UTF-8 (Dart's [jsonEncode] does not \u-escape them), matching the
  /// spec's worked examples.
  static String _encodeFlat(Map<String, String> map) {
    final keys = map.keys.toList()..sort();
    if (keys.isEmpty) return '{}\n';

    final buf = StringBuffer();
    buf.writeln('{');
    for (var i = 0; i < keys.length; i++) {
      buf.write('  ');
      buf.write(jsonEncode(keys[i]));
      buf.write(': ');
      buf.write(jsonEncode(map[keys[i]]));
      buf.writeln(i < keys.length - 1 ? ',' : '');
    }
    buf.writeln('}');
    return buf.toString();
  }
}

/// Output of [JsonAdapter.encode]: the encoded JSON plus diagnostics.
class JsonEncodeResult {
  JsonEncodeResult({required this.content, required this.collapsedKeys});

  /// Canonical JSON bytes ready for the writer.
  final String content;

  /// Keys whose ICU plural/select/selectordinal expression was collapsed
  /// to its `other` branch (flat-json only). Drives the lossy-event hint.
  final List<String> collapsedKeys;
}
