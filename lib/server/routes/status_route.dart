import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../project/dialect_project.dart';
import '../serializers.dart';

/// `GET /api/status` — per-locale coverage / missing / stale / locked.
Response statusHandler(DialectProject project) {
  return Response.ok(
    jsonEncode(statusJson(project)),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
