@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../_support/repo_root.dart';

/// `examples/after` is the project we point people at to see what a Dialect
/// repo looks like, so it has to survive the checks we tell them to run. It
/// did not: `settingsEmail` is deliberately "Email" in Vietnamese, which
/// tripped `source_equality` and made `--strict` exit 1 on our own canonical
/// example. Nothing tested the examples, so it rotted quietly.
///
/// These pin both halves of "canonical": the example passes the strictest
/// gate we ship, and it is already in the normalized shape `--fix` produces,
/// so a reader who runs `--fix` on it gets no diff.
void main() {
  group('examples/after (the canonical Dialect project)', () {
    final example = repoPath(['examples', 'after']);

    test('passes dialect check --strict', () async {
      final exit = await DialectCommandRunner().run(<String>[
        'check',
        '--strict',
        example,
      ]);
      expect(
        exit,
        0,
        reason:
            'The canonical example must pass the canonical check. An '
            'intentionally-untranslated value is locked in its @key block; '
            'anything else here is a real regression.',
      );
    });

    test('is already canonical — check --fix rewrites nothing', () async {
      // Copy out: --fix writes in place, and a test must not dirty the repo.
      final tmp = Directory.systemTemp.createTempSync('dialect_example_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      _copyDir(
        Directory(p.join(example, 'dialect')),
        p.join(tmp.path, 'dialect'),
      );

      final before = _arbBytes(tmp.path);
      expect(before, isNotEmpty, reason: 'copied no ARBs — bad test setup');

      final exit = await DialectCommandRunner().run(<String>[
        'check',
        '--fix',
        tmp.path,
      ]);
      expect(exit, 0);

      expect(
        _arbBytes(tmp.path),
        before,
        reason:
            'check --fix changed the example, so the committed example is not '
            'in canonical form. Run `dialect check --fix` in examples/after '
            'and commit the result.',
      );
    });
  });
}

/// `{ relative arb path: contents }` for every ARB under [root].
Map<String, String> _arbBytes(String root) {
  final out = <String, String>{};
  for (final f in Directory(root).listSync(recursive: true).whereType<File>()) {
    if (p.extension(f.path) != '.arb') continue;
    out[p.relative(f.path, from: root)] = f.readAsStringSync();
  }
  return out;
}

void _copyDir(Directory src, String dest) {
  for (final entity in src.listSync(recursive: true)) {
    if (entity is! File) continue;
    final target = p.join(dest, p.relative(entity.path, from: src.path));
    Directory(p.dirname(target)).createSync(recursive: true);
    entity.copySync(target);
  }
}
