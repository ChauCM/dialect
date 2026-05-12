import 'package:args/command_runner.dart';

class SyncCommand extends Command<int> {
  @override
  String get name => 'sync';

  @override
  String get description =>
      'Generate platform-specific files from canonical ARB sources.';

  @override
  Future<int> run() async {
    print('TODO: implement dialect sync (M5)');
    return 0;
  }
}
