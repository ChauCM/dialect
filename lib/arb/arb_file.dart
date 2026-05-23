/// In-memory representation of an ARB file.
///
/// ARB (Application Resource Bundle) is JSON with metadata. Each translation
/// key has a value (the string itself) and an optional matching `@key` block
/// describing it — see Dialect's convention in
/// `example/dialect/dialect.yaml` for the full shape.
///
/// This model is the substrate for every other v1.0 milestone:
/// - `dialect sync` reads and writes it (M5).
/// - `dialect check` validates structural and semantic rules on it (M4, M8).
/// - `dialect status` computes coverage and stale counts from it (M6).
/// - `dialect serve` exposes it over a REST API (M10).
library;

class ArbFile {
  ArbFile({
    required this.locale,
    required this.entries,
    this.fileMetadata = const {},
    this.orphanMetadata = const {},
    this.entryLines = const {},
    this.sourcePath,
  });

  /// IETF BCP 47 locale tag, e.g. `en`, `es`, `pt-BR`.
  final String locale;

  /// Translation entries, in the order they appear after parsing.
  /// `dialect check --fix` re-sorts these on write.
  final List<ArbEntry> entries;

  /// Other `@@<name>` file-level metadata, preserved verbatim so we never
  /// silently strip fields Dialect doesn't know about (e.g. Flutter
  /// `gen_l10n`'s `@@last_modified`, custom `@@x-context`). Keyed by the
  /// `@@`-prefixed name, value is the JSON-decoded payload.
  final Map<String, Object?> fileMetadata;

  /// `@key` metadata blocks whose corresponding key/value pair is missing.
  /// Preserved here (rather than silently dropped) so `dialect check` can
  /// flag them as a structural error. `dialect check --fix` strips them
  /// from the written output by construction — the writer never emits
  /// `orphanMetadata`.
  final Map<String, ArbMetadata> orphanMetadata;

  /// 1-based line numbers for each top-level key in the original source
  /// text. Populated by the parser via a post-decode scan; used by the
  /// `dialect check` report formatter to produce `file:line` hints.
  /// `jsonDecode` strips positions, so we re-derive them.
  final Map<String, int> entryLines;

  /// Path to the source file this ARB was parsed from, if known. Set by
  /// the project loader. Used by report formatting; `null` when the ARB
  /// came from an in-memory string (e.g. unit tests).
  final String? sourcePath;

  ArbEntry? entryFor(String key) {
    for (final e in entries) {
      if (e.key == key) return e;
    }
    return null;
  }
}

class ArbEntry {
  ArbEntry({required this.key, required this.value, this.metadata});

  final String key;
  final String value;

  /// `@key` block. Lives only in source ARBs by convention — translation
  /// ARBs are key/value-only and `dialect check --fix` strips metadata if
  /// found there.
  final ArbMetadata? metadata;

  /// Namespace prefix derived from the key, or null if the key is bare.
  /// E.g. `checkout.bookNow` → `checkout`; `loose_key` → null.
  String? get namespace {
    final dot = key.indexOf('.');
    if (dot <= 0) return null;
    return key.substring(0, dot);
  }

  ArbEntry copyWith({String? key, String? value, ArbMetadata? metadata}) {
    return ArbEntry(
      key: key ?? this.key,
      value: value ?? this.value,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ArbMetadata {
  ArbMetadata({
    this.description,
    this.context,
    this.placeholders,
    this.locked = false,
    this.glossaryExempt = false,
    this.sourceHash,
    this.extras = const {},
  });

  /// Required by convention for source ARBs: what this string means in context.
  final String? description;

  /// Optional disambiguation hint (e.g. `checkout_screen`, `shared`).
  final String? context;

  /// Placeholder declarations keyed by placeholder name.
  final Map<String, ArbPlaceholder>? placeholders;

  /// Pinned by a human reviewer; `dialect translate` skips this key.
  final bool locked;

  /// Skip the glossary-enforcement check on this key. Use when the source
  /// string uses a glossary term in a non-literal sense.
  final bool glossaryExempt;

  /// Hash of the canonical source string at lock-time. Powers `dialect
  /// status` "stale" detection (M6). Spec'd in `dialect/spec/icu-json.md`.
  final String? sourceHash;

  /// Preserved-as-is for forward compatibility. Unknown `@key.*` fields land
  /// here so the writer can pass them through.
  final Map<String, Object?> extras;

  ArbMetadata copyWith({
    String? description,
    String? context,
    Map<String, ArbPlaceholder>? placeholders,
    bool? locked,
    bool? glossaryExempt,
    Object? sourceHash = _sentinel,
    Map<String, Object?>? extras,
  }) {
    return ArbMetadata(
      description: description ?? this.description,
      context: context ?? this.context,
      placeholders: placeholders ?? this.placeholders,
      locked: locked ?? this.locked,
      glossaryExempt: glossaryExempt ?? this.glossaryExempt,
      // sourceHash uses an explicit sentinel so callers can pass `null`
      // to clear the field (unlock action) without colliding with the
      // "leave it alone" default.
      sourceHash: identical(sourceHash, _sentinel)
          ? this.sourceHash
          : sourceHash as String?,
      extras: extras ?? this.extras,
    );
  }

  static const Object _sentinel = Object();
}

class ArbPlaceholder {
  ArbPlaceholder({this.type, this.format, this.extras = const {}});

  /// `String`, `int`, `double`, `DateTime` — per ARB convention.
  final String? type;

  /// Format hint (e.g. `compactLong` for numbers, `yMMMd` for dates).
  final String? format;

  /// Preserved unknown fields.
  final Map<String, Object?> extras;
}
