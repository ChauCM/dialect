import 'package:args/command_runner.dart';

class InitCommand extends Command<int> {
  InitCommand() {
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Overwrite an existing dialect/ directory.',
    );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Scaffold the dialect/ directory in the current project.';

  @override
  Future<int> run() async {
    print('TODO: implement dialect init (M3)');
    return 0;
  }
}
