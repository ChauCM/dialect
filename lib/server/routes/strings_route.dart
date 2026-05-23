import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import '../../arb/arb_file.dart';
import '../../arb/arb_writer.dart';
import '../../arb/source_hash.dart';
import '../../project/dialect_project.dart';
import '../serializers.dart';

/// `GET /api/strings?locale=<loc>` — every source key with the matching
/// translation entry. Returns 400 if the locale is missing or unknown
/// to the project (i.e. not in `target_locales` and not the source
/// locale).
Response stringsListHandler(DialectProject project, Request req) {
  final locale = req.url.queryParameters['locale'];
  if (locale == null || locale.isEmpty) {
    return _jsonError(400, 'Missing `locale` query parameter.');
  }
  final isSource = locale == project.config.sourceLocale;
  final isTarget = project.config.targetLocales.contains(locale);
  if (!isSource && !isTarget) {
    return _jsonError(
      404,
      'Locale `$locale` is not configured (source: '
      '`${project.config.sourceLocale}`, '
      'targets: ${project.config.targetLocales}).',
    );
  }
  return Response.ok(
    jsonEncode(stringsJson(project, locale)),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

/// `PUT /api/strings/<key>` — update a translation (or source) value.
///
/// Body shape:
/// ```
/// {
///   "locale": "es",
///   "value": "Reservar ahora",
///   "locked": true,           // optional; only meaningful when locale != source
///   "glossary_exempt": false  // optional; only meaningful when locale == source
/// }
/// ```
///
/// Side effects:
/// - The target ARB file at `dialect/translations/<locale>.arb` (or
///   `dialect/source/<locale>.arb` for the source locale) is rewritten
///   in canonical form via `ArbWriter`. The file mtime updates only
///   when the desired bytes differ from disk (M5 idempotency contract).
/// - Locking writes `@key.source_hash` from the current source value
///   per `dialect/spec/source_hash.md`. Unlocking clears it.
/// - For the source locale, the request may set `glossary_exempt` on
///   the `@key` block.
Future<Response> stringsPutHandler(
  DialectProject project,
  Request req,
  String key,
) async {
  final bodyText = await req.readAsString();
  Map<String, Object?> body;
  try {
    final decoded = jsonDecode(bodyText);
    if (decoded is! Map<String, Object?>) {
      return _jsonError(400, 'Body must be a JSON object.');
    }
    body = decoded;
  } on FormatException catch (e) {
    return _jsonError(400, 'Body is not valid JSON: ${e.message}');
  }

  final locale = body['locale'];
  if (locale is! String || locale.isEmpty) {
    return _jsonError(400, '`locale` is required and must be a string.');
  }
  final value = body['value'];
  if (value is! String) {
    return _jsonError(400, '`value` is required and must be a string.');
  }
  final lockedReq = body['locked'];
  if (lockedReq != null && lockedReq is! bool) {
    return _jsonError(400, '`locked` must be a boolean when provided.');
  }
  final exemptReq = body['glossary_exempt'];
  if (exemptReq != null && exemptReq is! bool) {
    return _jsonError(
      400,
      '`glossary_exempt` must be a boolean when provided.',
    );
  }

  final isSource = locale == project.config.sourceLocale;
  final isTarget = project.config.targetLocales.contains(locale);
  if (!isSource && !isTarget) {
    return _jsonError(404, 'Locale `$locale` is not configured.');
  }

  // Look up the source entry by key. PUT may create a missing
  // translation but not a new source key (that's `dialect import`'s job).
  final sourceEntry = project.source.entryFor(key);
  if (sourceEntry == null) {
    return _jsonError(404, 'Unknown source key `$key`.');
  }

  final updatedArb = isSource
      ? _applySourceUpdate(
          project,
          key: key,
          value: value,
          glossaryExempt: exemptReq as bool?,
        )
      : _applyTranslationUpdate(
          project,
          locale: locale,
          key: key,
          value: value,
          sourceValue: sourceEntry.value,
          locked: lockedReq as bool?,
        );

  // Write back via ArbWriter for canonical formatting.
  final path = _arbPath(project, locale: locale, isSource: isSource);
  final desired = ArbWriter.encode(updatedArb);
  final file = File(path);
  file.parent.createSync(recursive: true);
  final currentBytes = file.existsSync() ? file.readAsStringSync() : null;
  if (currentBytes != desired) {
    file.writeAsStringSync(desired);
  }

  return Response.ok(
    jsonEncode({'key': key, 'locale': locale, 'value': value}),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

ArbFile _applySourceUpdate(
  DialectProject project, {
  required String key,
  required String value,
  bool? glossaryExempt,
}) {
  final src = project.source;
  final updated = <ArbEntry>[];
  for (final entry in src.entries) {
    if (entry.key != key) {
      updated.add(entry);
      continue;
    }
    final meta = entry.metadata ?? ArbMetadata();
    updated.add(
      entry.copyWith(
        value: value,
        metadata: glossaryExempt == null
            ? meta
            : meta.copyWith(glossaryExempt: glossaryExempt),
      ),
    );
  }
  return ArbFile(
    locale: src.locale,
    entries: updated,
    fileMetadata: src.fileMetadata,
    orphanMetadata: src.orphanMetadata,
    entryLines: src.entryLines,
    sourcePath: src.sourcePath,
  );
}

ArbFile _applyTranslationUpdate(
  DialectProject project, {
  required String locale,
  required String key,
  required String value,
  required String sourceValue,
  bool? locked,
}) {
  final arb =
      project.translations[locale] ??
      ArbFile(locale: locale, entries: const []);
  final updated = <ArbEntry>[];
  var found = false;
  for (final entry in arb.entries) {
    if (entry.key != key) {
      updated.add(entry);
      continue;
    }
    found = true;
    updated.add(_applyToEntry(entry, value, locked, sourceValue));
  }
  if (!found) {
    updated.add(
      _applyToEntry(ArbEntry(key: key, value: ''), value, locked, sourceValue),
    );
  }
  return ArbFile(
    locale: arb.locale,
    entries: updated,
    fileMetadata: arb.fileMetadata,
    orphanMetadata: arb.orphanMetadata,
    entryLines: arb.entryLines,
    sourcePath: arb.sourcePath,
  );
}

ArbEntry _applyToEntry(
  ArbEntry existing,
  String value,
  bool? locked,
  String sourceValue,
) {
  if (locked == null) {
    return existing.copyWith(value: value);
  }
  final currentMeta = existing.metadata ?? ArbMetadata();
  if (locked) {
    final nextMeta = currentMeta.copyWith(
      locked: true,
      sourceHash: computeSourceHash(sourceValue),
    );
    return existing.copyWith(value: value, metadata: nextMeta);
  }
  final unlocked = currentMeta.copyWith(locked: false, sourceHash: null);
  // Drop the metadata block entirely when nothing useful remains. The
  // convention is "translation ARBs are key/value-only" (see
  // dialect.yaml header) — keeping an empty `@key: {}` block would be
  // noise. ArbEntry.copyWith can't clear `metadata` to null (passing
  // null means "leave it alone"), so construct directly when clearing.
  if (_isMetadataEffectivelyEmpty(unlocked)) {
    return ArbEntry(key: existing.key, value: value);
  }
  return existing.copyWith(value: value, metadata: unlocked);
}

bool _isMetadataEffectivelyEmpty(ArbMetadata m) {
  return m.description == null &&
      m.context == null &&
      (m.placeholders == null || m.placeholders!.isEmpty) &&
      !m.locked &&
      !m.glossaryExempt &&
      m.sourceHash == null &&
      m.extras.isEmpty;
}

String _arbPath(
  DialectProject project, {
  required String locale,
  required bool isSource,
}) {
  return p.join(
    project.root,
    'dialect',
    isSource ? 'source' : 'translations',
    '$locale.arb',
  );
}

Response _jsonError(int status, String message) {
  return Response(
    status,
    body: jsonEncode({'error': message}),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
