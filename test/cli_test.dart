import 'package:args/command_runner.dart';
import 'package:dialect/cli.dart';
import 'package:test/test.dart';

void main() {
  group('DialectCommandRunner', () {
    test('exposes every v1.0 command', () {
      final runner = DialectCommandRunner();
      expect(
        runner.commands.keys.toSet(),
        containsAll(<String>{
          'init',
          'import',
          'describe',
          'sync',
          'check',
          'status',
          'serve',
        }),
      );
    });

    test('--version exits 0', () async {
      final runner = DialectCommandRunner();
      expect(await runner.run(['--version']), 0);
    });

    test('--help exits cleanly', () async {
      final runner = DialectCommandRunner();
      // CommandRunner's built-in help handler prints usage and returns null.
      // `bin/dialect.dart` maps null to exit code 0.
      expect((await runner.run(['--help'])) ?? 0, 0);
    });

    test('subcommand --help exits cleanly', () async {
      final runner = DialectCommandRunner();
      expect((await runner.run(['init', '--help'])) ?? 0, 0);
    });

    test('unknown command throws UsageException', () {
      final runner = DialectCommandRunner();
      expect(
        () => runner.run(['no-such-command']),
        throwsA(isA<UsageException>()),
      );
    });

    // M10 landed real implementations for every v1.0 command; no
    // stub-only tests remain. Per-command behavior is covered in
    // test/commands/<name>_test.dart and test/server/.
  });
}
