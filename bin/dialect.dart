import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dialect/cli.dart';

Future<void> main(List<String> arguments) async {
  try {
    final exitCode = await DialectCommandRunner().run(arguments);
    exit(exitCode ?? 0);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(e.usage);
    exit(64); // EX_USAGE
  }
}
