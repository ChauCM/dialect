import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../project/dialect_project.dart';
import '../serializers.dart';

/// `GET /api/config` — returns the parsed dialect.yaml shape.
Response configHandler(DialectProject project) {
  return Response.ok(
    jsonEncode(configJson(project)),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
