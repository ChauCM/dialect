@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/arb/source_hash.dart';
import 'package:dialect/cli.dart';
import 'package:dialect/commands/status.dart';
import 'package:dialect/config/dialect_config.dart';
import 'package:dialect/project/dialect_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('computeStatus', () {
    test('100% coverage when every source key is translated', () {
      final p = _project(
        targetLocales: ['es'],
        source: _arb('en', entries: [_entry('common.cancel', 'Cancel')]),
        translations: {
          'es': _arb('es', entries: [_entry('common.cancel', 'Cancelar')]),
        },
      );
      final rows = computeStatus(p);
      expect(rows, hasLength(1));
      expect(rows.first.coverage, 1.0);
      expect(rows.first.missing, 0);
      expect(rows.first.stale, 0);
      expect(rows.first.locked, 0);
    });

    test('counts missing keys (new = source - translation)', () {
      final p = _project(
        targetLocales: ['es'],
        source: _arb(
          'en',
          entries: [_entry('a', 'A'), _entry('b', 'B'), _entry('c', 'C')],
        ),
        translations: {
          'es': _arb('es', entries: [_entry('a', 'A')]),
        },
      );
      final row = computeStatus(p).single;
      expect(row.coverage, closeTo(1 / 3, 1e-6));
      expect(row.missing, 2);
    });

    test('treats a missing translation file as 0% coverage', () {
      final p = _project(
        targetLocales: ['ja'],
        source: _arb('en', entries: [_entry('a', 'A')]),
        // No 'ja' entry in translations map.
      );
      final row = computeStatus(p).single;
      expect(row.coverage, 0.0);
      expect(row.missing, 1);
    });

    test('counts locked translations as `locked`', () {
      final p = _project(
        targetLocales: ['es'],
        source: _arb('en', entries: [_entry('a', 'A')]),
        translations: {
          'es': _arb(
            'es',
            entries: [
              ArbEntry(
                key: 'a',
                value: 'A-es',
                metadata: ArbMetadata(locked: true),
              ),
            ],
          ),
        },
      );
      expect(computeStatus(p).single.locked, 1);
    });

    test('source_hash mismatch on a locked entry → stale', () {
      // Build a project whose `es` translation locks a translation
      // against a STALE source_hash. The source value has since changed
      // → mismatch → stale.
      final source = _arb(
        'en',
        entries: [_entry('a', 'Book Now')], // current source
      );
      final outdatedHash = computeSourceHash('Book this stay'); // OLD
      final es = _arb(
        'es',
        entries: [
          ArbEntry(
            key: 'a',
            value: 'Reservar ahora',
            metadata: ArbMetadata(locked: true, sourceHash: outdatedHash),
          ),
        ],
      );
      final p = _project(
        targetLocales: ['es'],
        source: source,
        translations: {'es': es},
      );
      final row = computeStatus(p).single;
      expect(row.locked, 1);
      expect(row.stale, 1);
    });

    test('locked + matching source_hash → not stale', () {
      final source = _arb('en', entries: [_entry('a', 'Book Now')]);
      final currentHash = computeSourceHash('Book Now');
      final es = _arb(
        'es',
        entries: [
          ArbEntry(
            key: 'a',
            value: 'Reservar ahora',
            metadata: ArbMetadata(locked: true, sourceHash: currentHash),
          ),
        ],
      );
      final p = _project(
        targetLocales: ['es'],
        source: source,
        translations: {'es': es},
      );
      final row = computeStatus(p).single;
      expect(row.locked, 1);
      expect(row.stale, 0);
    });

    test('pre-spec lock (no source_hash) is not stale', () {
      // Backward compat: an old lock with no hash field is `locked` but
      // not `stale`. Spec at dialect/spec/source_hash.md.
      final source = _arb('en', entries: [_entry('a', 'Book Now')]);
      final es = _arb(
        'es',
        entries: [
          ArbEntry(
            key: 'a',
            value: 'Reservar ahora',
            metadata: ArbMetadata(locked: true /* no sourceHash */),
          ),
        ],
      );
      final p = _project(
        targetLocales: ['es'],
        source: source,
        translations: {'es': es},
      );
      final row = computeStatus(p).single;
      expect(row.locked, 1);
      expect(row.stale, 0);
    });

    test('unlocked entries are never stale, even with a source_hash', () {
      final source = _arb('en', entries: [_entry('a', 'Book Now')]);
      final es = _arb(
        'es',
        entries: [
          ArbEntry(
            key: 'a',
            value: 'Reservar ahora',
            metadata: ArbMetadata(
              // locked: false (default)
              sourceHash: 'stalehashvalue00',
            ),
          ),
        ],
      );
      final p = _project(
        targetLocales: ['es'],
        source: source,
        translations: {'es': es},
      );
      final row = computeStatus(p).single;
      expect(row.locked, 0);
      expect(row.stale, 0);
    });
  });

  group('dialect status (integration)', () {
    test(
      'renders a clean status table against the canonical fixture',
      () async {
        final exit = await DialectCommandRunner().run(<String>[
          'status',
          _canonicalFixture(),
        ]);
        expect(exit, 0);
      },
    );

    test('errors gracefully when run outside a project', () async {
      final tmp = Directory.systemTemp.createTempSync('dialect_status_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final exit = await DialectCommandRunner().run(<String>[
        'status',
        tmp.path,
      ]);
      expect(exit, 66);
    });
  });
}

DialectProject _project({
  required List<String> targetLocales,
  required ArbFile source,
  Map<String, ArbFile> translations = const {},
}) {
  return DialectProject(
    root: '<test>',
    config: DialectConfig(sourceLocale: 'en', targetLocales: targetLocales),
    source: source,
    translations: translations,
  );
}

ArbFile _arb(String locale, {List<ArbEntry> entries = const []}) {
  return ArbFile(locale: locale, entries: entries);
}

ArbEntry _entry(String key, String value) => ArbEntry(key: key, value: value);

String _canonicalFixture() {
  // Walk up until pubspec.yaml exists; same pattern as test/_support.
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return p.join(dir.path, 'test', 'fixtures', 'canonical');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('cwd has no pubspec ancestor');
    }
    dir = parent;
  }
}
