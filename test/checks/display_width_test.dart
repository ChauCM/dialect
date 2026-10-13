import 'package:dialect/checks/display_width.dart';
import 'package:test/test.dart';

void main() {
  group('displayColumns', () {
    test('Latin is one column per character', () {
      expect(displayColumns('Edit profile'), 12);
      expect(displayColumns(''), 0);
    });

    test('East Asian Wide and Fullwidth are two columns', () {
      expect(displayColumns('외움'), 4); // Hangul syllables
      expect(displayColumns('学习'), 4); // hanzi
      expect(displayColumns('ひらカナ'), 8); // kana
      expect(displayColumns('。、'), 4); // CJK punctuation
      expect(displayColumns('ＡＢ１'), 6); // fullwidth forms
      expect(displayColumns('𠀀'), 2); // CJK extension B
    });

    test('mixed text adds up', () {
      expect(displayColumns('Level 외움'), 10);
    });

    test('combining marks keep one column each', () {
      expect(displayColumns('Chỉnh sửa'), 9);
      expect(displayColumns('Chỉnh sửa'), 12);
    });
  });
}
