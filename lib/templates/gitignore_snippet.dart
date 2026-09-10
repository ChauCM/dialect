// GENERATED FILE — do not edit by hand.
// Run `dart run tool/sync_templates.dart` to regenerate.
// Source of truth: `templates/gitignore_snippet`.

// dart format off
const String gitignoreSnippet = r'''# Dialect ephemeral plan files (regenerated each command run).
# .dialect/state.json is NOT ephemeral — it is the acknowledgement ledger,
# and `dialect check --strict` reads it. Commit it, or a fresh clone fails a
# gate on warnings someone already adjudicated.
.dialect/*-plan.md
''';
// dart format on
