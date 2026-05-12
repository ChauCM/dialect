import 'package:args/command_runner.dart';

class StatusCommand extends Command<int> {
  @override
  String get name => 'status';

  @override
  String get description => 'Show translation coverage per locale.';

  @override
  Future<int> run() async {
    print('TODO: implement dialect status (M6)');
    return 0;
  }
}
