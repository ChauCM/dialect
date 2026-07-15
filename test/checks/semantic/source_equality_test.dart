import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/checks/semantic/source_equality.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('SourceEqualityRule', () {
    test('warns when translation equals source byte-for-byte', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'common.cancel', value: 'Cancel')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'common.cancel', value: 'Cancel')],
          ),
        },
      );
      final issues = const SourceEqualityRule().run(p);
      expect(issues, hasLength(1));
      expect(issues.first.ruleName, 'source_equality');
      expect(issues.first.locale, 'es');
      expect(issues.first.key, 'common.cancel');
      // The hint has to name the file-based escape hatch, not just the
      // dashboard: locking in a `@key` block is the git-friendly path, and
      // it is the only one available to someone reading CI output.
      expect(issues.first.hint, contains('"locked": true'));
      expect(issues.first.hint, contains('@common.cancel'));
    });

    test('does not warn when translation differs from source', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'common.cancel', value: 'Cancel')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [ArbEntry(key: 'common.cancel', value: 'Cancelar')],
          ),
        },
      );
      expect(const SourceEqualityRule().run(p), isEmpty);
    });

    test('does not warn when source locale is the target locale', () {
      // The source ARB itself is never compared to itself.
      final p = project(
        targetLocales: const ['en'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'common.ok', value: 'OK')],
        ),
        translations: {
          'en': arb(
            locale: 'en',
            entries: [ArbEntry(key: 'common.ok', value: 'OK')],
          ),
        },
      );
      expect(const SourceEqualityRule().run(p), isEmpty);
    });

    test('does not warn when the translation entry is locked', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'brand.name', value: 'Spotify')],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(
                key: 'brand.name',
                value: 'Spotify',
                metadata: ArbMetadata(locked: true),
              ),
            ],
          ),
        },
      );
      expect(const SourceEqualityRule().run(p), isEmpty);
    });

    test('skips short or symbol-only values', () {
      final p = project(
        targetLocales: const ['es'],
        source: arb(
          locale: 'en',
          entries: [
            ArbEntry(key: 'a', value: '•'),
            ArbEntry(key: 'b', value: '42'),
            ArbEntry(key: 'c', value: 'X'),
          ],
        ),
        translations: {
          'es': arb(
            locale: 'es',
            entries: [
              ArbEntry(key: 'a', value: '•'),
              ArbEntry(key: 'b', value: '42'),
              ArbEntry(key: 'c', value: 'X'),
            ],
          ),
        },
      );
      expect(const SourceEqualityRule().run(p), isEmpty);
    });

    test('warns on short-but-still-suspect "OK" / "Hi"', () {
      final p = project(
        targetLocales: const ['ja'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'common.ok', value: 'OK!')],
        ),
        translations: {
          'ja': arb(
            locale: 'ja',
            entries: [ArbEntry(key: 'common.ok', value: 'OK!')],
          ),
        },
      );
      expect(const SourceEqualityRule().run(p), hasLength(1));
    });
  });
}
