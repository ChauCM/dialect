import 'package:dialect/render/table.dart';
import 'package:test/test.dart';

void main() {
  group('renderTable', () {
    test('renders the dialect status header + rows', () {
      final out = renderTable([
        ['Locale', 'Coverage', 'Stale'],
        ['es', '100%', '0'],
        ['ja', '97.2%', '5'],
      ]);
      // Verify the structure: top border, header, mid border, two rows,
      // bottom border. The exact alignment is the next assertion.
      final lines = out.split('\n');
      expect(lines.length, greaterThanOrEqualTo(6));
      expect(lines.first.startsWith('┌'), isTrue);
      expect(lines.first.endsWith('┐'), isTrue);
      expect(lines[2].startsWith('├'), isTrue);
      expect(lines[lines.length - 1].startsWith('└'), isTrue);
    });

    test('right-aligns numeric data columns', () {
      final out = renderTable([
        ['Locale', 'Stale'],
        ['es', '5'],
        ['ja', '127'],
      ]);
      // Right-alignment in the wider data column means both numbers end
      // at the same column index — `5` is preceded by padding spaces,
      // `127` fills the cell. Find each row's closing `│` of the data
      // cell and assert they align.
      final lines = out.split('\n');
      final esLine = lines.firstWhere((l) => l.contains('es'));
      final jaLine = lines.firstWhere((l) => l.contains('ja'));
      expect(esLine.indexOf('5 │'), greaterThan(0));
      expect(jaLine.indexOf('7 │'), greaterThan(0));
      expect(
        esLine.indexOf('5 │'),
        jaLine.indexOf('7 │'),
        reason: 'numeric column right-aligns: digits end at the same column',
      );
    });

    test('left-aligns string columns and the header row', () {
      final out = renderTable([
        ['Locale', 'Coverage'],
        ['es', '100%'],
      ]);
      // The header is always left-aligned ("Locale", "Coverage" both
      // start in column 2 of their cells).
      expect(out.contains('│ Locale '), isTrue);
      expect(out.contains('│ Coverage '), isTrue);
    });

    test('rejects rows with inconsistent column counts', () {
      expect(
        () => renderTable([
          ['A', 'B'],
          ['1', '2', '3'],
        ]),
        throwsArgumentError,
      );
    });

    test('handles an empty grid', () {
      expect(renderTable(const []), '');
    });
  });
}
