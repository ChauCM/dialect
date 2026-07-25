import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/arb/source_hash.dart';
import 'package:dialect/checks/rule.dart';
import 'package:dialect/checks/structural/lock_integrity.dart';
import 'package:test/test.dart';

import '../_helpers.dart';

void main() {
  group('LockIntegrityRule', () {
    test(
      'flags a bare boolean lock as an error, with the repair in the hint',
      () {
        final p = project(
          targetLocales: ['vi'],
          source: arb(
            locale: 'en',
            entries: [ArbEntry(key: 'settingsEmail', value: 'Email')],
          ),
          translations: {
            'vi': arb(
              locale: 'vi',
              entries: [
                ArbEntry(
                  key: 'settingsEmail',
                  value: 'Email',
                  metadata: ArbMetadata(locked: true), // no source_hash
                ),
              ],
            ),
          },
        );
        final issues = const LockIntegrityRule().run(p);
        expect(issues, hasLength(1));
        expect(issues.first.severity, IssueSeverity.error);
        expect(issues.first.message, contains('bare lock'));
        // The repair must be runnable straight from the report, with the
        // dashboard offered as the alternative rather than the only route.
        expect(issues.first.hint, contains('dialect lock'));
        expect(issues.first.hint, contains('dialect serve'));
      },
    );

    test('passes a lock that carries its source_hash', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'settingsEmail', value: 'Email')],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(
                key: 'settingsEmail',
                value: 'Email',
                metadata: ArbMetadata(
                  locked: true,
                  sourceHash: computeSourceHash('Email'),
                ),
              ),
            ],
          ),
        },
      );
      expect(const LockIntegrityRule().run(p), isEmpty);
    });

    test('ignores unlocked entries with or without hashes', () {
      final p = project(
        targetLocales: ['vi'],
        source: arb(
          locale: 'en',
          entries: [ArbEntry(key: 'a', value: 'A')],
        ),
        translations: {
          'vi': arb(
            locale: 'vi',
            entries: [
              ArbEntry(
                key: 'a',
                value: 'Á',
                metadata: ArbMetadata(sourceHash: computeSourceHash('A')),
              ),
            ],
          ),
        },
      );
      expect(const LockIntegrityRule().run(p), isEmpty);
    });
  });
}
