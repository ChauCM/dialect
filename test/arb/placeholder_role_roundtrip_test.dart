import 'package:dialect/arb/arb_parser.dart';
import 'package:dialect/arb/arb_writer.dart';
import 'package:test/test.dart';

void main() {
  test('role round-trips through parse and write', () {
    const src = '''
{
  "@@locale": "en",
  "walkBandOpensAtStep": "Goal {goal} opens now at step {step}.",
  "@walkBandOpensAtStep": {
    "namespace": "app",
    "description": "Banner.",
    "placeholders": {
      "goal": { "type": "int", "role": "identifier", "example": "1" },
      "step": { "type": "int", "role": "identifier", "example": "1" }
    }
  }
}
''';
    final file = ArbParser.parse(src, sourcePath: 'en.arb');
    final ph = file.entries.first.metadata!.placeholders!['goal']!;
    expect(ph.role, 'identifier');
    expect(ph.type, 'int');
    expect(ph.extras['example'], '1');

    final out = ArbWriter.encode(file);
    expect(out, contains('"role": "identifier"'));
    final again = ArbParser.parse(out, sourcePath: 'en.arb');
    expect(
      again.entries.first.metadata!.placeholders!['step']!.role,
      'identifier',
    );
  });
}
