import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../project/dialect_project.dart';
import '../server/embedded_assets.dart';
import '../server/server.dart';

class ServeCommand extends Command<int> {
  ServeCommand() {
    argParser
      ..addOption(
        'port',
        help: 'Port to bind the local server to.',
        defaultsTo: '4077',
      )
      ..addOption(
        'host',
        help: 'Interface to bind. Default `localhost` is loopback only.',
        defaultsTo: 'localhost',
      );
  }

  @override
  String get name => 'serve';

  @override
  String get description =>
      'Start the local web UI for reviewing and editing translations.';

  @override
  String get invocation => 'dialect serve [path]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final rest = results.rest;
    if (rest.length > 1) {
      stderr.writeln('serve takes at most one positional argument.');
      return 64;
    }
    final root = rest.isEmpty
        ? Directory.current.path
        : p.normalize(p.absolute(rest.first));

    final portRaw = results['port'] as String;
    final port = int.tryParse(portRaw);
    if (port == null || port < 0 || port > 65535) {
      stderr.writeln('--port must be an integer 0–65535, got `$portRaw`.');
      return 64;
    }
    final host = results['host'] as String;

    // Eager-load once just to surface "no project" early — the
    // request middleware re-loads on every call.
    try {
      DialectProject.load(root);
    } on FileSystemException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(
        'Run `dialect init` first, or pass the project root as an argument.',
      );
      return 66;
    } on FormatException catch (e) {
      stderr.writeln('dialect.yaml or an ARB file is malformed:');
      stderr.writeln('  ${e.message}');
      return 65;
    }

    final HttpServer server;
    try {
      server = await startServer(projectRoot: root, host: host, port: port);
    } on SocketException catch (e) {
      stderr.writeln(
        'Could not bind $host:$port — ${e.osError?.message ?? e.message}.',
      );
      stderr.writeln(
        'Try a different port with `--port`, or stop the process holding it.',
      );
      return 1;
    }

    stdout.writeln('Dialect Review running at http://$host:${server.port}');
    stdout.writeln('Reading from: $root');
    if (!hasEmbeddedDashboard) {
      stdout.writeln('');
      stdout.writeln(
        '  Note: SPA assets are not bundled in this build. The REST API is live,',
      );
      stdout.writeln(
        '  but http://$host:${server.port}/ will show a "not built yet" page.',
      );
      stdout.writeln(
        '  Bake the dashboard in: `dart run tool/build_dashboard.dart`',
      );
    }
    stdout.writeln('');
    stdout.writeln('Press Ctrl-C to stop.');

    // Block until the user kills the process. Tests use `startServer`
    // directly instead of going through `run()`, so they don't need
    // to wait on this.
    final done = Completer<void>();
    final sigint = ProcessSignal.sigint.watch().listen((_) {
      stdout.writeln('\nStopping…');
      done.complete();
    });
    await done.future;
    await sigint.cancel();
    await server.close(force: true);
    return 0;
  }
}
