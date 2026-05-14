/// Inspect ICU MessageFormat strings — extract placeholder names and the
/// plural categories used in a `{var, plural, …}` expression.
///
/// **Scope.** This is a focused scanner, not a full ICU parser. It's
/// designed for v1.0's two structural-check needs:
///
///   - `placeholder_match`: ensure every `{name}` in the source also appears
///     in every translation, and no new names are introduced.
///   - `plural_categories`: when the source string is a plural expression,
///     ensure each translation includes the CLDR categories required for
///     its locale.
///
/// **Supported.**
///   - Simple placeholders: `Hello {name}` → `{name}`.
///   - Typed placeholders: `{count, number}`, `{date, date, yMMMd}`.
///   - Plural expressions at any nesting depth (the scanner recurses into
///     each branch).
///   - Select expressions (treated as a non-plural typed placeholder by
///     `extractPluralCategories`, but their variable name is extracted by
///     `extractPlaceholders`).
///   - ICU escapes: `''` → literal `'`; `'…'` quoted run when the run
///     contains `{`, `}`, `|`, or `#` (per the ICU 4.8+ "auto-quoting"
///     rules).
///
/// **Out of scope for v1.0.** Argument formatting beyond name + first
/// keyword (e.g. detailed `number` skeleton inspection). If a v1.1+ check
/// rule needs deeper analysis we will swap in a real ICU parser.
library;

class IcuMessage {
  const IcuMessage._();

  /// All placeholder variable names referenced in [message], recursing into
  /// plural/select branches. The same name appearing twice is returned once.
  static Set<String> extractPlaceholders(String message) {
    final result = <String>{};
    _walk(message, (expr) {
      if (expr.varName != null) result.add(expr.varName!);
    });
    return result;
  }

  /// Categories used in the first (outermost) `{var, plural, …}` expression
  /// in [message], in source order. Returns `null` if no plural expression
  /// is found.
  ///
  /// Examples:
  ///   `'{n, plural, =0{x} =1{y} other{z}}'` → `['=0', '=1', 'other']`.
  ///   `'Hello {name}'` → `null`.
  ///   `'{n, plural, zero{…} one{…} two{…} few{…} many{…} other{…}}'`
  ///     → `['zero', 'one', 'two', 'few', 'many', 'other']`.
  static List<String>? extractPluralCategories(String message) {
    List<String>? found;
    _walk(message, (expr) {
      if (found != null) return;
      if (expr.type == 'plural' || expr.type == 'selectordinal') {
        found = expr.branches!.map((b) => b.name).toList();
      }
    });
    return found;
  }

  /// True if [message] contains any ICU expression (`{name}` or
  /// `{var, …, …}`). False for plain strings (no `{}` at all, or only
  /// escaped braces).
  static bool hasExpressions(String message) {
    var any = false;
    _walk(message, (_) => any = true);
    return any;
  }

  static void _walk(String s, void Function(_Expr) visit) {
    for (final expr in _parseExpressions(s)) {
      visit(expr);
      final branches = expr.branches;
      if (branches != null) {
        for (final branch in branches) {
          _walk(branch.body, visit);
        }
      }
    }
  }

  /// Parse top-level `{…}` expressions in [s]. Ignores text outside braces.
  static List<_Expr> _parseExpressions(String s) {
    final result = <_Expr>[];
    var i = 0;
    while (i < s.length) {
      final ch = s.codeUnitAt(i);
      if (ch == _apos) {
        i = _skipQuotedRun(s, i);
        continue;
      }
      if (ch == _open) {
        final end = _matchClose(s, i);
        if (end == -1) {
          // Unmatched `{` — malformed. Stop scanning.
          break;
        }
        result.add(_parseExpr(s.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
      i++;
    }
    return result;
  }

  /// Parse the contents of `{` ... `}` (the inside, not including the braces).
  ///
  /// Forms:
  ///   - `name`                  → simple placeholder
  ///   - `name, plural, …`       → plural expression
  ///   - `name, selectordinal, …` → ordinal plural
  ///   - `name, select, …`       → select expression
  ///   - `name, number[, …]`     → typed (treated as simple for our needs)
  ///   - `name, date[, …]`       → typed
  ///   - `name, time[, …]`       → typed
  static _Expr _parseExpr(String inside) {
    final firstComma = _findTopLevelComma(inside);
    if (firstComma == -1) {
      // `{name}` — simple placeholder.
      final name = inside.trim();
      return _Expr(varName: name.isEmpty ? null : name);
    }

    final varName = inside.substring(0, firstComma).trim();
    final rest = inside.substring(firstComma + 1).trimLeft();
    final secondComma = _findTopLevelComma(rest);
    final type = (secondComma == -1 ? rest : rest.substring(0, secondComma))
        .trim()
        .toLowerCase();

    if (type == 'plural' ||
        type == 'selectordinal' ||
        type == 'select') {
      final body = secondComma == -1 ? '' : rest.substring(secondComma + 1);
      final branches = _parseBranches(body);
      return _Expr(varName: varName, type: type, branches: branches);
    }

    // Typed but not plural/select: number/date/time/etc. The variable name
    // is still a placeholder.
    return _Expr(varName: varName, type: type);
  }

  /// Parse plural/select branches: a whitespace-separated sequence of
  /// `selector { body }` pairs.
  static List<_Branch> _parseBranches(String body) {
    final result = <_Branch>[];
    var i = 0;
    while (i < body.length) {
      // Skip whitespace.
      while (i < body.length && _isWhitespace(body.codeUnitAt(i))) {
        i++;
      }
      if (i >= body.length) break;

      // Read selector (until `{`).
      final selectorStart = i;
      while (i < body.length && body.codeUnitAt(i) != _open) {
        if (body.codeUnitAt(i) == _apos) {
          i = _skipQuotedRun(body, i);
        } else {
          i++;
        }
      }
      if (i >= body.length) break;
      final selector = body.substring(selectorStart, i).trim();
      if (selector.isEmpty) break;

      // Read braced body.
      final bodyEnd = _matchClose(body, i);
      if (bodyEnd == -1) break;
      final branchBody = body.substring(i + 1, bodyEnd);
      result.add(_Branch(name: selector, body: branchBody));
      i = bodyEnd + 1;
    }
    return result;
  }

  /// Find the index of the matching `}` for the `{` at `openIdx`,
  /// honoring nested braces and ICU escape sequences. Returns -1 if no
  /// matching close is found.
  static int _matchClose(String s, int openIdx) {
    var depth = 0;
    var i = openIdx;
    while (i < s.length) {
      final ch = s.codeUnitAt(i);
      if (ch == _apos) {
        i = _skipQuotedRun(s, i);
        continue;
      }
      if (ch == _open) {
        depth++;
      } else if (ch == _close) {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    return -1;
  }

  /// Find the first comma at the top level of `s` (i.e. not inside any
  /// nested `{…}`). Returns -1 if none.
  static int _findTopLevelComma(String s) {
    var depth = 0;
    var i = 0;
    while (i < s.length) {
      final ch = s.codeUnitAt(i);
      if (ch == _apos) {
        i = _skipQuotedRun(s, i);
        continue;
      }
      if (ch == _open) {
        depth++;
      } else if (ch == _close) {
        depth--;
      } else if (depth == 0 && ch == _comma) {
        return i;
      }
      i++;
    }
    return -1;
  }

  /// ICU escape:
  ///   - `''` at position [i] consumes 2 chars and represents a literal `'`.
  ///   - `'` followed by `{`, `}`, `|`, or `#` starts a quoted run that
  ///     ends at the next standalone `'`.
  ///   - `'` followed by anything else is itself a literal `'`.
  /// Returns the index *after* the consumed sequence.
  static int _skipQuotedRun(String s, int i) {
    if (i + 1 >= s.length) return i + 1;
    final next = s.codeUnitAt(i + 1);
    if (next == _apos) {
      return i + 2; // '' is a literal apostrophe.
    }
    if (next != _open && next != _close && next != _pipe && next != _hash) {
      return i + 1; // Standalone apostrophe, not an escape.
    }
    // Consume until the closing `'`.
    var j = i + 2;
    while (j < s.length) {
      if (s.codeUnitAt(j) == _apos) {
        return j + 1;
      }
      j++;
    }
    return s.length;
  }

  static bool _isWhitespace(int code) =>
      code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;
}

class _Expr {
  _Expr({this.varName, this.type, this.branches});
  final String? varName;
  final String? type;
  final List<_Branch>? branches;
}

class _Branch {
  _Branch({required this.name, required this.body});
  final String name;
  final String body;
}

const int _open = 0x7B; // {
const int _close = 0x7D; // }
const int _apos = 0x27; // '
const int _comma = 0x2C; // ,
const int _pipe = 0x7C; // |
const int _hash = 0x23; // #
