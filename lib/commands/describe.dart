import 'package:args/command_runner.dart';

class DescribeCommand extends Command<int> {
  @override
  String get name => 'describe';

  @override
  String get description =>
      'Write an AI-pointer plan that backfills @description fields from callsites.';

  @override
  Future<int> run() async {
    print('TODO: implement dialect describe (M7)');
    return 0;
  }
}
