/// Render a 2-D string grid as a Unicode box-drawing table — the kind
/// `dialect status` and `dialect check` summaries use.
///
/// No deps. Right-aligns numeric-looking cells (everything that parses
/// as a number); left-aligns text. Header row is always the first row
/// of [rows].
///
/// ```
/// ┌────────┬──────────┬───────┬─────┐
/// │ Locale │ Coverage │ Stale │ New │
/// ├────────┼──────────┼───────┼─────┤
/// │ es     │     98.5 │     3 │  12 │
/// │ ja     │     97.2 │     5 │  12 │
/// └────────┴──────────┴───────┴─────┘
/// ```
String renderTable(List<List<String>> rows) {
  if (rows.isEmpty) return '';
  final cols = rows.first.length;
  final widths = List<int>.filled(cols, 0);
  for (final row in rows) {
    if (row.length != cols) {
      throw ArgumentError(
        'renderTable: every row must have $cols columns; got ${row.length}',
      );
    }
    for (var i = 0; i < cols; i++) {
      if (row[i].length > widths[i]) widths[i] = row[i].length;
    }
  }
  // Header row is `rows[0]`; rest are data rows. Decide alignment per
  // column from the data rows only (so a string header above numeric
  // data doesn't force left-align).
  final rightAlign = List<bool>.filled(cols, true);
  for (var i = 0; i < cols; i++) {
    for (var r = 1; r < rows.length; r++) {
      if (!_isNumeric(rows[r][i])) {
        rightAlign[i] = false;
        break;
      }
    }
  }
  // Header row stays left-aligned for readability even when data is numeric.

  final buf = StringBuffer();
  buf.writeln(_border(widths, _BorderStyle.top));
  for (var r = 0; r < rows.length; r++) {
    _writeRow(buf, rows[r], widths, rightAlign, header: r == 0);
    if (r == 0) buf.writeln(_border(widths, _BorderStyle.mid));
  }
  buf.write(_border(widths, _BorderStyle.bottom));
  return buf.toString();
}

void _writeRow(
  StringBuffer buf,
  List<String> row,
  List<int> widths,
  List<bool> rightAlign, {
  required bool header,
}) {
  buf.write('│');
  for (var i = 0; i < row.length; i++) {
    final cell = row[i];
    final pad = widths[i] - cell.length;
    final aligned = header || !rightAlign[i]
        ? ' $cell${' ' * pad} '
        : ' ${' ' * pad}$cell ';
    buf.write(aligned);
    buf.write('│');
  }
  buf.writeln();
}

enum _BorderStyle { top, mid, bottom }

String _border(List<int> widths, _BorderStyle style) {
  final (left, sep, right, line) = switch (style) {
    _BorderStyle.top => ('┌', '┬', '┐', '─'),
    _BorderStyle.mid => ('├', '┼', '┤', '─'),
    _BorderStyle.bottom => ('└', '┴', '┘', '─'),
  };
  final parts = widths.map((w) => line * (w + 2)).join(sep);
  return '$left$parts$right';
}

bool _isNumeric(String s) {
  if (s.isEmpty) return false;
  // Allow leading sign, digits, optional decimal, optional `%` suffix.
  final t = s.endsWith('%') ? s.substring(0, s.length - 1) : s;
  return double.tryParse(t) != null;
}
