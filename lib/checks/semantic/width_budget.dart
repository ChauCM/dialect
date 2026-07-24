import '../../arb/arb_file.dart';
import '../../arb/icu_message.dart';
import '../../project/dialect_project.dart';
import '../rule.dart';

/// Warn when a string is too long for the UI slot it renders in.
///
/// This is the "size-aware translation" guard. Text expands when
/// translated — "Edit profile" (12) → "Chỉnh sửa trang cá nhân" (23) — and
/// a faithful-but-long value silently breaks a tight button. The
/// [LengthRatioRule] can't catch that: 23/12 is 1.9×, well inside its
/// `[0.3, 2.5]` smell-band. What's missing is a budget tied to the *slot*.
///
/// **Opt-in by construction.** A key is only checked if its SOURCE `@key`
/// block declares a budget. Body copy, legal text, empty-state prose —
/// anything with room — is never annotated and never policed.
///
/// Two ways to declare a budget on the source `@key`:
///
/// ```jsonc
/// "editProfile": "Edit profile",
/// "@editProfile": { "x-slot": "button" }      // policy from dialect.yaml
///
/// "statusChip": "Live",
/// "@statusChip": { "x-max-length": 6 }         // hard character cap
/// ```
///
/// Slot policies live once in `dialect.yaml`:
///
/// ```yaml
/// slots:
///   button: { max_ratio: 1.4 }   # stay within ~1.4× the source ("similar length")
///   chip:   { max_length: 10 }   # a real pixel slot → absolute cap
///   tab:    { max_ratio: 1.2, grace: 2 }
/// ```
///
/// A `max_ratio` budget is `max(round(sourceLen × ratio), sourceLen +
/// grace)` — the grace floor (default [_defaultGrace]) keeps the shortest
/// labels ("Save" → "Lưu") from tripping on a ratio that's meaningless at
/// 3 chars. `max_length` is absolute and can flag an over-tight source
/// (English itself busting the slot) as well as a translation.
///
/// **Severity is warning, and `--strict` alone does NOT promote it** — like
/// `length_ratio`, it needs the explicit `--strict-length` opt-in. A button
/// that runs a few chars long is a nudge for the next author/agent to
/// tighten, not a reason to fail the build. It's a convention, enforced
/// softly (and ack-able), by design.
///
/// Length is measured on the *literal* text ([IcuMessage.literalText]) in
/// Unicode code points, so ICU placeholder names don't inflate the count.
/// A value with runtime placeholders is inherently fuzzy to budget; put
/// budgets on tight static labels, which is where overflow actually bites.
class WidthBudgetRule extends Rule {
  const WidthBudgetRule();

  /// Extra characters a `max_ratio` budget always allows on top of the
  /// source length, so tiny strings don't false-trip. Overridable
  /// per-slot with `grace:`.
  static const int _defaultGrace = 4;

  @override
  String get name => 'width_budget';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.warning;

  @override
  List<Issue> run(DialectProject project) {
    final slots = _parseSlots(project);

    // Resolve each source key's budget once. No budget → key is invisible
    // to this rule (the opt-in guarantee).
    final budgetByKey = <String, _Budget>{};
    for (final src in project.source.entries) {
      final b = _resolveBudget(src, slots);
      if (b != null) budgetByKey[src.key] = b;
    }
    if (budgetByKey.isEmpty) return const [];

    final issues = <Issue>[];
    final sourceByKey = <String, ArbEntry>{
      for (final e in project.source.entries) e.key: e,
    };

    // Source side: an absolute cap the English itself busts is a genuine
    // "this slot is impossible" finding. (A ratio budget's floor is
    // >= sourceLen, so source never trips there.)
    for (final src in project.source.entries) {
      final b = budgetByKey[src.key];
      if (b == null) continue;
      final srcLen = _len(src.value);
      if (srcLen == 0) continue;
      final maxChars = b.maxChars(srcLen);
      if (srcLen > maxChars) {
        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message:
                'Source `${src.key}` is $srcLen chars — over its '
                '${b.label} budget of $maxChars. The slot is too tight even '
                'for the source string.',
            key: src.key,
            file: project.source.sourcePath,
            line: project.source.entryLines[src.key],
            hint:
                'Either widen the slot / raise the budget, or shorten the '
                'source copy. Every translation inherits this budget, so an '
                'impossible source guarantees downstream overflow.',
          ),
        );
      }
    }

    // Translation side: the common case — a faithful translation that
    // outgrew the slot.
    for (final entry in project.translations.entries) {
      final locale = entry.key;
      if (locale == project.config.sourceLocale) continue;
      final arb = entry.value;

      for (final t in arb.entries) {
        final b = budgetByKey[t.key];
        if (b == null) continue;
        final src = sourceByKey[t.key];
        if (src == null) continue;
        final srcLen = _len(src.value);
        if (srcLen == 0) continue;
        final maxChars = b.maxChars(srcLen);
        final tLen = _len(t.value);
        if (tLen <= maxChars) continue;

        issues.add(
          Issue(
            severity: defaultSeverity,
            ruleName: name,
            message:
                'Translation for `${t.key}` is $tLen chars — over the '
                '${b.label} budget of $maxChars (source is $srcLen).',
            locale: locale,
            key: t.key,
            file: arb.sourcePath,
            line: arb.entryLines[t.key],
            hint:
                'This renders in a tight UI slot. Use the shortest faithful '
                'form (context often makes words droppable — a profile-header '
                '"Edit profile" can be just "Edit"). Keep glossary terms '
                'intact. If the slot genuinely has room, raise or remove the '
                'budget on the source `@${t.key}` block, or ack this warning.',
          ),
        );
      }
    }

    return issues;
  }

  /// Length of a value's literal copy, in Unicode code points. Placeholder
  /// names are stripped so `"{count} left"` measures `" left"`, not the
  /// identifier.
  static int _len(String value) => IcuMessage.literalText(value).runes.length;

  /// Resolve a source entry's budget from its `@key` metadata, or `null`
  /// when it declares none. Inline `x-max-length` (a hard cap) wins over a
  /// named `x-slot`.
  static _Budget? _resolveBudget(ArbEntry src, Map<String, _Slot> slots) {
    final extras = src.metadata?.extras;
    if (extras == null || extras.isEmpty) return null;

    final inline = _asInt(extras['x-max-length']);
    if (inline != null && inline > 0) {
      return _Budget.absolute(inline, '`x-max-length`');
    }

    final slotName = extras['x-slot'];
    if (slotName is String) {
      final slot = slots[slotName];
      // An x-slot pointing at an undeclared slot is silently ignored rather
      // than treated as an error — the slot vocabulary is the project's to
      // define, and a hard failure here would punish a half-configured repo.
      if (slot == null) return null;
      if (slot.maxLength != null) {
        return _Budget.absolute(slot.maxLength!, 'slot `$slotName`');
      }
      if (slot.maxRatio != null) {
        return _Budget.ratio(
          slot.maxRatio!,
          slot.grace ?? _defaultGrace,
          'slot `$slotName`',
        );
      }
    }
    return null;
  }

  /// Parse the `slots:` block out of `DialectConfig.extras`. Tolerant of
  /// missing/partial data — a slot with neither `max_length` nor
  /// `max_ratio` is dropped (nothing to enforce).
  static Map<String, _Slot> _parseSlots(DialectProject project) {
    final raw = project.config.extras['slots'];
    if (raw is! Map) return const {};
    final out = <String, _Slot>{};
    for (final entry in raw.entries) {
      final name = entry.key;
      if (name is! String) continue;
      final v = entry.value;
      if (v is! Map) continue;
      final maxLength = _asInt(v['max_length']);
      final maxRatio = _asDouble(v['max_ratio']);
      final grace = _asInt(v['grace']);
      if (maxLength == null && maxRatio == null) continue;
      out[name] = _Slot(maxLength: maxLength, maxRatio: maxRatio, grace: grace);
    }
    return out;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    return null;
  }
}

/// A resolved budget for one key: either an absolute character cap or a
/// ratio-relative-to-source cap with a grace floor.
class _Budget {
  _Budget.absolute(int chars, this.label)
    : _absolute = chars,
      _ratio = null,
      _grace = 0;
  _Budget.ratio(double ratio, int grace, this.label)
    : _absolute = null,
      _ratio = ratio,
      _grace = grace;

  final int? _absolute;
  final double? _ratio;
  final int _grace;

  /// Human-readable budget source for messages, e.g. `slot \`button\`` or
  /// `` `x-max-length` ``.
  final String label;

  /// The effective character cap given the source's literal length.
  int maxChars(int sourceLen) {
    if (_absolute != null) return _absolute;
    final byRatio = (sourceLen * _ratio!).round();
    final floor = sourceLen + _grace;
    return byRatio > floor ? byRatio : floor;
  }
}

/// One slot policy from `dialect.yaml`'s `slots:` block.
class _Slot {
  _Slot({this.maxLength, this.maxRatio, this.grace});
  final int? maxLength;
  final double? maxRatio;
  final int? grace;
}

/// The budget resolved for a source key, for callers outside the rule
/// (e.g. `dialect translate` inlining the constraint into its plan).
class WidthBudgetInfo {
  WidthBudgetInfo({
    required this.maxChars,
    required this.sourceChars,
    required this.label,
  });

  /// Effective character cap.
  final int maxChars;

  /// Literal length of the source string (the ratio base).
  final int sourceChars;

  /// Budget source, e.g. `slot \`button\``.
  final String label;
}

/// Resolve the width budget for [src] under [project], or `null` if the
/// key declares none. Shared so `dialect translate` can show the agent the
/// exact budget the check enforces, with no duplicated resolution logic.
WidthBudgetInfo? widthBudgetFor(ArbEntry src, DialectProject project) {
  final slots = WidthBudgetRule._parseSlots(project);
  final b = WidthBudgetRule._resolveBudget(src, slots);
  if (b == null) return null;
  final srcLen = WidthBudgetRule._len(src.value);
  if (srcLen == 0) return null;
  return WidthBudgetInfo(
    maxChars: b.maxChars(srcLen),
    sourceChars: srcLen,
    label: b.label,
  );
}
