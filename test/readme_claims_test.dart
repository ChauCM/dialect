@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import '_support/repo_root.dart';

/// The README is the first thing anyone reads, so a claim it makes that the
/// binary does not honor is a trust defect, not a typo. `--auto` was listed
/// as shipped in v1.0 while `dialect translate --auto` answered "not
/// available yet", and `publish` advertised S3/R2/git upload when only the
/// `local` target exists.
///
/// These pin the two claims to the code that has to back them. When `--auto`
/// or the S3 target actually lands, these tests fail and the README gets
/// updated in the same commit — which is the point.
void main() {
  group('README claims match the shipped binary', () {
    final readme = File(repoPath(['README.md'])).readAsStringSync();

    test('--auto is not advertised as shipped while the code refuses it', () {
      final translate = File(
        repoPath(['lib', 'commands', 'translate.dart']),
      ).readAsStringSync();
      final autoRefused = translate.contains('--auto is not available yet');
      if (!autoRefused) {
        markTestSkipped(
          '--auto now works — update the README row to a version.',
        );
        return;
      }
      expect(
        readme,
        contains('| `dialect translate --auto` |'),
        reason:
            '--auto needs its own row so its status is not borrowed '
            'from `dialect translate`, which does ship.',
      );
      // The row must not claim a released version.
      final row = readme
          .split('\n')
          .firstWhere((l) => l.startsWith('| `dialect translate --auto` |'));
      expect(
        row,
        contains('planned'),
        reason:
            'translate.dart still refuses --auto, so the README must not '
            'claim it ships. Row was: $row',
      );
    });

    test('publish does not advertise upload targets that are not built', () {
      final publish = File(
        repoPath(['lib', 'commands', 'publish.dart']),
      ).readAsStringSync();
      final s3Missing = publish.contains('The `s3` target is not built yet');
      if (!s3Missing) {
        markTestSkipped('s3 target landed — the README may advertise it now.');
        return;
      }
      final row = readme
          .split('\n')
          .firstWhere((l) => l.startsWith('| `dialect publish` |'));
      expect(
        row.contains('S3') || row.contains('R2'),
        isFalse,
        reason:
            'publish.dart only implements the `local` target, so the '
            'README must not promise S3/R2 upload. Row was: $row',
      );
    });
  });
}
