/// Display width of a string, in terminal-style columns.
///
/// East Asian Wide and Fullwidth code points are two columns, everything else
/// one. A combining mark is still one column of its own (there is no
/// zero-width handling), so a decomposed Vietnamese letter measures wider than
/// its precomposed form, exactly as it did when checks counted code points.
/// Emoji are not counted wide.
///
/// The one implementation behind `width_budget` and `length_ratio`: a slot cap
/// and a length ratio are both about how much room a string takes, and two
/// definitions would let a Korean label pass one and trip the other.
int displayColumns(String value) {
  var columns = 0;
  for (final r in value.runes) {
    columns += _isWide(r) ? 2 : 1;
  }
  return columns;
}

/// Whether [r] is East Asian Wide or Fullwidth: Hangul jamo and syllables, CJK
/// ideographs (including the extensions and compatibility block), kana, CJK
/// symbols and punctuation, and the fullwidth forms.
bool _isWide(int r) =>
    (r >= 0x1100 && r <= 0x115F) || // Hangul Jamo
    (r >= 0x2E80 && r <= 0x303E) || // CJK radicals, symbols, punctuation
    (r >= 0x3041 && r <= 0x33FF) || // kana, Hangul compat., CJK letters
    (r >= 0x3400 && r <= 0x4DBF) || // CJK extension A
    (r >= 0x4E00 && r <= 0x9FFF) || // CJK unified ideographs
    (r >= 0xA000 && r <= 0xA4CF) || // Yi
    (r >= 0xA960 && r <= 0xA97F) || // Hangul Jamo extended-A
    (r >= 0xAC00 && r <= 0xD7A3) || // Hangul syllables
    (r >= 0xF900 && r <= 0xFAFF) || // CJK compatibility ideographs
    (r >= 0xFE30 && r <= 0xFE6F) || // CJK compatibility forms
    (r >= 0xFF01 && r <= 0xFF60) || // fullwidth forms
    (r >= 0xFFE0 && r <= 0xFFE6) || // fullwidth signs
    (r >= 0x20000 && r <= 0x3FFFD); // CJK extensions B and beyond
