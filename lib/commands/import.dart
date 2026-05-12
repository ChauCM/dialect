import 'package:args/command_runner.dart';

class ImportCommand extends Command<int> {
  ImportCommand() {
    argParser
      ..addOption(
        'from',
        help: 'Source format to import from.',
        allowed: ['arb'],
        defaultsTo: 'arb',
      )
      ..addOption(
        'path',
        help: 'Path to the source ARB file or directory to import.',
      );
  }

  @override
  String get name => 'import';

  @override
  String get description =>
      'Write an AI-pointer plan that imports existing ARBs into the Dialect convention.';

  @override
  Future<int> run() async {
    print('TODO: implement dialect import (M7)');
    return 0;
  }
}
