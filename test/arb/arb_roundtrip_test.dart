@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/arb/arb_writer.dart';
import 'package:test/test.dart';

void main() {
  group('ARB round-trip', () {
    test('round-trips example/dialect/source/en.arb byte-identically', () {
      final file = File('example/dialect/source/en.arb');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'seed fixture should exist',
      );
      final source = file.readAsStringSync();

      final arb = ArbParser.parse(source);
      final emitted = ArbWriter.encode(arb);

      expect(
        emitted,
        equals(source),
        reason:
            'writer output must be byte-identical to the canonical seed; '
            'a diff here means either the writer drifted from convention '
            'or the seed file is not in canonical form',
      );
    });

    test('parse → write → parse → write is stable', () {
      // For any input the writer accepts, applying the round-trip a second
      // time must produce the same output as the first.
      final file = File('example/dialect/source/en.arb');
      final source = file.readAsStringSync();

      final first = ArbWriter.encode(ArbParser.parse(source));
      final second = ArbWriter.encode(ArbParser.parse(first));
      expect(second, first);
    });
  });
}
