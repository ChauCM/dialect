import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'commands/check.dart';
import 'commands/describe.dart';
import 'commands/import.dart';
import 'commands/init.dart';
import 'commands/serve.dart';
import 'commands/status.dart';
import 'commands/sync.dart';
import 'version.dart';

class DialectCommandRunner extends CommandRunner<int> {
  DialectCommandRunner()
      : super(
          'dialect',
          'AI-native localization for Flutter-led teams.',
        ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the tool version and exit.',
    );

    addCommand(InitCommand());
    addCommand(ImportCommand());
    addCommand(DescribeCommand());
    addCommand(SyncCommand());
    addCommand(CheckCommand());
    addCommand(StatusCommand());
    addCommand(ServeCommand());
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.flag('version')) {
      print('dialect $dialectVersion');
      return 0;
    }
    return super.runCommand(topLevelResults);
  }
}
