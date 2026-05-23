/// JSON DTOs the dashboard consumes.
///
/// Kept here, not on the ARB model, so the wire shape can evolve
/// independently of the on-disk shape. The dashboard's REST API contract
/// lives in `docs/architecture.md` § REST API.
library;

import '../arb/arb_file.dart';
import '../arb/source_hash.dart';
import '../commands/status.dart';
import '../glossary/glossary_loader.dart';
import '../project/dialect_project.dart';

/// `GET /api/config` payload.
Map<String, Object?> configJson(DialectProject project) {
  return {
    'source_locale': project.config.sourceLocale,
    'target_locales': project.config.targetLocales,
    'platforms': {
      for (final entry in project.config.platforms.entries)
        entry.key: {
          'output': entry.value.output,
          'format': entry.value.format,
          'namespaces': entry.value.namespaces,
        },
    },
    'project_name': _projectName(project),
  };
}

/// `GET /api/strings?locale=<loc>` payload — every source key with the
/// matching translation value + metadata. Keys that have no entry in
/// the requested locale's ARB are still listed with `translation:
/// null` and `missing: true`.
Map<String, Object?> stringsJson(DialectProject project, String locale) {
  final translation = project.translations[locale];
  final translationByKey = <String, ArbEntry>{};
  if (translation != null) {
    for (final e in translation.entries) {
      translationByKey[e.key] = e;
    }
  }

  final entries = <Map<String, Object?>>[];
  for (final src in project.source.entries) {
    final translated = translationByKey[src.key];
    final meta = translated?.metadata;
    final currentHash = computeSourceHash(src.value);
    final stale =
        meta?.locked == true &&
        meta?.sourceHash != null &&
        meta?.sourceHash != currentHash;
    entries.add({
      'key': src.key,
      'namespace': src.namespace,
      'source': src.value,
      'translation': translated?.value,
      'description': src.metadata?.description,
      'context': src.metadata?.context,
      'placeholders': src.metadata?.placeholders == null
          ? <String, Object?>{}
          : {
              for (final p in src.metadata!.placeholders!.entries)
                p.key: {
                  if (p.value.type != null) 'type': p.value.type,
                  if (p.value.format != null) 'format': p.value.format,
                },
            },
      'locked': meta?.locked ?? false,
      'glossary_exempt': src.metadata?.glossaryExempt ?? false,
      'source_hash': meta?.sourceHash,
      'current_source_hash': currentHash,
      'stale': stale,
      'missing': translated == null,
    });
  }
  return {
    'locale': locale,
    'source_locale': project.config.sourceLocale,
    'entries': entries,
  };
}

/// `GET /api/glossary` payload.
Map<String, Object?> glossaryJson(Glossary glossary) {
  return {
    'terms': [
      for (final t in glossary.terms)
        {'term': t.term, 'meaning': t.meaning, 'translations': t.translations},
    ],
  };
}

/// `GET /api/status` payload. Reuses the M6 [computeStatus] math so the
/// dashboard footer and the `dialect status` CLI agree byte-for-byte.
Map<String, Object?> statusJson(DialectProject project) {
  final rows = computeStatus(project);
  return {
    'rows': [
      for (final r in rows)
        {
          'locale': r.locale,
          'coverage': r.coverage,
          'missing': r.missing,
          'stale': r.stale,
          'locked': r.locked,
        },
    ],
  };
}

String _projectName(DialectProject project) {
  final raw = project.config.extras['project'];
  if (raw is Map<String, Object?>) {
    final name = raw['name'];
    if (name is String && name.isNotEmpty) return name;
  }
  return 'Your project';
}
