/// Token substitution for the M7 plan templates.
///
/// The seed Markdown at `templates/import_plan.md` and
/// `templates/describe_plan.md` carries `{{TOKEN}}` placeholders. This
/// renderer expands them from the loaded [DialectProject]. Token shape:
/// uppercase identifier inside double braces, no whitespace. Unknown
/// tokens are left untouched so a typo in the seed is loud, not silent.
library;

import '../project/dialect_project.dart';

/// Expand `{{TOKEN}}` placeholders in [template] using the values in
/// [tokens]. Tokens are case-sensitive; missing tokens are left in
/// place so they show up in the rendered plan (and any test that
/// snapshots the output).
String renderPlanTemplate(String template, Map<String, String> tokens) {
  var out = template;
  for (final entry in tokens.entries) {
    out = out.replaceAll('{{${entry.key}}}', entry.value);
  }
  return out;
}

/// Tokens common to both `import` and `describe` plans, derived from
/// the loaded project. Commands layer their own command-specific
/// tokens (`FROM`, `PATH`, …) on top.
Map<String, String> commonPlanTokens(DialectProject project) {
  final projectName = _projectName(project);
  final namespaces = _namespacesAcrossPlatforms(project);
  return {
    'SOURCE_LOCALE': project.config.sourceLocale,
    'TARGET_LOCALES': project.config.targetLocales.isEmpty
        ? '(none configured yet)'
        : project.config.targetLocales.join(', '),
    'PROJECT_NAME': projectName,
    'NAMESPACES': namespaces.isEmpty
        ? '(none configured yet)'
        : namespaces.join(', '),
    'GENERATED_AT': DateTime.now().toUtc().toIso8601String(),
  };
}

String _projectName(DialectProject project) {
  final raw = project.config.extras['project'];
  if (raw is Map<String, Object?>) {
    final name = raw['name'];
    if (name is String && name.isNotEmpty) return name;
  }
  return 'Your project';
}

/// Union of namespaces across every configured platform. Order is
/// stable (sorted) so the rendered plan is deterministic.
List<String> _namespacesAcrossPlatforms(DialectProject project) {
  final set = <String>{};
  for (final p in project.config.platforms.values) {
    set.addAll(p.namespaces);
  }
  final list = set.toList()..sort();
  return list;
}
