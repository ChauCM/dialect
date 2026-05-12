import 'package:args/command_runner.dart';

class ServeCommand extends Command<int> {
  ServeCommand() {
    argParser.addOption(
      'port',
      help: 'Port to bind the local server to.',
      defaultsTo: '4077',
    );
  }

  @override
  String get name => 'serve';

  @override
  String get description =>
      'Start the local web UI for reviewing and editing translations.';

  @override
  Future<int> run() async {
    print('TODO: implement dialect serve (M10)');
    return 0;
  }
}
