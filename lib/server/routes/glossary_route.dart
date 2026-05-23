import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../project/dialect_project.dart';
import '../serializers.dart';

/// `GET /api/glossary` — returns the parsed glossary.yaml shape.
Response glossaryHandler(DialectProject project) {
  return Response.ok(
    jsonEncode(glossaryJson(project.glossary)),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
