import 'package:args/command_runner.dart';

class CheckCommand extends Command<int> {
  CheckCommand() {
    argParser
      ..addFlag(
        'strict',
        negatable: false,
        help: 'Promote warnings to errors (CI mode).',
      )
      ..addFlag(
        'strict-length',
        negatable: false,
        help: 'Also promote length-ratio warnings to errors.',
      )
      ..addFlag(
        'fix',
        negatable: false,
        help: 'Normalize ARB files in place (sort, @@locale first, '
            '@key block placement, strip metadata from translations).',
      );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Validate translation completeness and correctness.';

  @override
  Future<int> run() async {
    print('TODO: implement dialect check (M4 structural / M8 semantic)');
    return 0;
  }
}
