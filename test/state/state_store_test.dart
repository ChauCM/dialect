import 'package:dialect/state/state_store.dart';
import 'package:test/test.dart';

void main() {
  group('StateStore', () {
    test('empty store encodes to version + empty checks', () {
      expect(
        StateStore().encode(),
        '{\n'
        '  "version": 1,\n'
        '  "checks": {}\n'
        '}\n',
      );
    });

    test('round-trips an ack record', () {
      const json =
          '{\n'
          '  "version": 1,\n'
          '  "checks": {\n'
          '    "source_equality:vi:settingsEmailLabel": {\n'
          '      "acknowledged": "969ccbd3cf6300ec",\n'
          '      "acknowledged_at": "2026-05-30T13:01:15Z",\n'
          '      "note": "Email is canonical in vi"\n'
          '    }\n'
          '  }\n'
          '}\n';
      expect(StateStore.parse(json).encode(), json);
    });

    test('sorts check keys lexicographically on write', () {
      final store = StateStore();
      store.checks['glossary:ar:zeta'] = AckRecord(acknowledged: 'bbbb');
      store.checks['glossary:ar:alpha'] = AckRecord(acknowledged: 'aaaa');
      final out = store.encode();
      expect(out.indexOf('alpha'), lessThan(out.indexOf('zeta')));
    });

    test('preserves unknown top-level and record fields (forward-compat)', () {
      const json =
          '{\n'
          '  "version": 1,\n'
          '  "future_top": {"x": 1},\n'
          '  "checks": {\n'
          '    "glossary:ar:foo": {\n'
          '      "acknowledged": "aaaa",\n'
          '      "acknowledged_by": "dev@example.com",\n'
          '      "future_field": true\n'
          '    }\n'
          '  }\n'
          '}\n';
      final out = StateStore.parse(json).encode();
      expect(out, contains('"future_top"'));
      expect(out, contains('"acknowledged_by": "dev@example.com"'));
      expect(out, contains('"future_field": true'));
    });

    test('rejects non-object root', () {
      expect(() => StateStore.parse('[]'), throwsA(isA<FormatException>()));
    });

    test('rejects invalid JSON', () {
      expect(() => StateStore.parse('{nope'), throwsA(isA<FormatException>()));
    });
  });
}
