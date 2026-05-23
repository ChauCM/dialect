/// Shelf bootstrap for `dialect serve`.
///
/// Mounts the REST API at `/api/*` and serves the embedded SPA from
/// the binary itself (no `node_modules` on disk at runtime). Each
/// request reloads the project from disk so external edits to ARB
/// files are visible immediately — the project is tiny, the I/O is
/// cheap, and it removes the "stale-cache" foot-gun.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../project/dialect_project.dart';
import 'embedded_assets.dart';
import 'routes/config_route.dart';
import 'routes/glossary_route.dart';
import 'routes/status_route.dart';
import 'routes/strings_route.dart';

/// Build the Shelf [Handler] for [projectRoot]. Pulled out of the
/// `serve` command so tests can drive it without binding a real port.
Handler buildHandler(String projectRoot) {
  final router = Router();

  router.get('/api/config', (Request _) {
    final project = _loadOrFail(projectRoot);
    return configHandler(project);
  });

  router.get('/api/glossary', (Request _) {
    final project = _loadOrFail(projectRoot);
    return glossaryHandler(project);
  });

  router.get('/api/status', (Request _) {
    final project = _loadOrFail(projectRoot);
    return statusHandler(project);
  });

  router.get('/api/strings', (Request req) {
    final project = _loadOrFail(projectRoot);
    return stringsListHandler(project, req);
  });

  router.put('/api/strings/<key>', (Request req, String key) async {
    final project = _loadOrFail(projectRoot);
    return stringsPutHandler(project, req, key);
  });

  // Unknown /api/* paths return JSON 404 rather than falling through
  // to the SPA handler (which would happily serve HTML).
  router.all('/api/<rest|.*>', (Request _) {
    return Response.notFound(
      jsonEncode({'error': 'No such API endpoint.'}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });

  // Static assets — index.html + bundled JS/CSS — fall through to the
  // SPA handler. Anything outside /api/* gets served from the embedded
  // bundle; unknown paths return index.html so client-side routing
  // works ("/strings", "/glossary", …).
  router.all('/<rest|.*>', _staticAssetHandler);

  return const Pipeline()
      .addMiddleware(_corsHeaders())
      .addMiddleware(_errorAsJson())
      .addHandler(router.call);
}

/// Bind the Shelf handler on `host:port`. Returns the live [HttpServer]
/// so the caller (the `serve` command) can keep the process alive.
Future<HttpServer> startServer({
  required String projectRoot,
  String host = 'localhost',
  int port = 4077,
}) async {
  final handler = buildHandler(projectRoot);
  return shelf_io.serve(handler, host, port);
}

DialectProject _loadOrFail(String projectRoot) {
  // Throws here propagate to the error middleware, which turns them
  // into JSON 500s rather than the default Shelf HTML error page.
  return DialectProject.load(projectRoot);
}

Response _staticAssetHandler(Request req) {
  final path = req.url.path;
  // The router matched `/<rest|.*>`; req.url.path is the requested
  // path with no leading slash (Shelf convention).
  final keys = embeddedAssets.keys;
  if (keys.isEmpty) {
    return Response.ok(
      _emptyDashboardHtml,
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  }

  // Direct hit on a known asset.
  final direct = path.isEmpty ? 'index.html' : path;
  if (embeddedAssets.containsKey(direct)) {
    return Response.ok(
      embeddedAssets[direct],
      headers: {'content-type': _contentTypeFor(direct)},
    );
  }

  // SPA fallback — unknown path serves index.html.
  if (embeddedAssets.containsKey('index.html')) {
    return Response.ok(
      embeddedAssets['index.html'],
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  }
  return Response.notFound('Not found: $path');
}

String _contentTypeFor(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0) return 'application/octet-stream';
  switch (path.substring(i + 1).toLowerCase()) {
    case 'html':
      return 'text/html; charset=utf-8';
    case 'js':
    case 'mjs':
      return 'application/javascript; charset=utf-8';
    case 'css':
      return 'text/css; charset=utf-8';
    case 'json':
      return 'application/json; charset=utf-8';
    case 'svg':
      return 'image/svg+xml';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'ico':
      return 'image/x-icon';
    case 'woff':
      return 'font/woff';
    case 'woff2':
      return 'font/woff2';
    default:
      return 'application/octet-stream';
  }
}

/// Permissive CORS so the user can run the SPA from `pnpm dev` against
/// the Dart server during dashboard development. The server is bound
/// to localhost; this is not a security boundary.
Middleware _corsHeaders() {
  return (inner) {
    return (req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: _corsResponseHeaders);
      }
      final res = await inner(req);
      return res.change(headers: {...res.headers, ..._corsResponseHeaders});
    };
  };
}

const Map<String, String> _corsResponseHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, PUT, POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
};

/// Turn uncaught exceptions inside route handlers into JSON 500s. The
/// default Shelf error page is HTML and unhelpful for an API.
Middleware _errorAsJson() {
  return (inner) {
    return (req) async {
      try {
        return await inner(req);
      } on FileSystemException catch (e) {
        return Response(
          503,
          body: jsonEncode({'error': 'Could not load project: ${e.message}'}),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      } on FormatException catch (e) {
        return Response(
          500,
          body: jsonEncode({'error': 'Malformed file: ${e.message}'}),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      } catch (e, st) {
        stderr.writeln('dialect serve: $e\n$st');
        return Response.internalServerError(
          body: jsonEncode({'error': '$e'}),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
    };
  };
}

/// Tiny HTML page shown when the SPA hasn't been baked in yet. Gets
/// the dev unstuck with one command.
const String _emptyDashboardHtml = '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Dialect dashboard — not built yet</title>
    <style>
      body { font: 14px/1.5 system-ui, sans-serif; max-width: 640px;
             margin: 40px auto; padding: 0 24px; color: #222; }
      code { background: #eef; padding: 2px 6px; border-radius: 4px; }
      h1 { font-size: 22px; }
    </style>
  </head>
  <body>
    <h1>Dashboard not bundled in this build</h1>
    <p>The REST API at <code>/api/*</code> is live, but the SPA hasn't
    been embedded into the Dart binary yet.</p>
    <p>To bake it in:</p>
    <pre><code>cd dashboard
pnpm install
pnpm build
cd ..
dart run tool/build_dashboard.dart</code></pre>
    <p>Then re-run <code>dialect serve</code> (or rebuild your
    <code>dart compile exe</code> binary).</p>
  </body>
</html>
''';
