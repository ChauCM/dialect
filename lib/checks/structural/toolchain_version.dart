import 'package:path/path.dart' as p;

import '../../project/dialect_project.dart';
import '../../version.dart';
import '../rule.dart';

/// Fail when the `dialect` binary on PATH is older than the project's
/// declared `toolchain.min_version`.
///
/// A `dialect.yaml` teaches both the CLI and an AI agent how the project
/// works, and some of what it promises is only true of a new enough binary.
/// The sharp example is `sync`: before 1.2 it silently **deleted** keys that
/// lived only in generated output, reported success, and left `check` green.
/// A project that relies on the guard has no way to say so, and the failure
/// is invisible until data is gone.
///
/// Projects used to encode this as a prose "pinned toolchain" comment at the
/// top of `dialect.yaml`. That is folklore: nobody re-derives it, it drifts
/// from the binary it names (real example: a block claiming one version while
/// its rebuild step checked out a different commit), and it cannot fire. The
/// CLI already knows its own version, and the project can state its floor —
/// so this rule closes the loop.
///
/// **Severity is error, not warning.** The consequence of running too old a
/// binary is silent data loss, and a warning is exactly what scrolls past on
/// the day it matters. The fix is always cheap: upgrade the binary, or lower
/// the floor if it was set too high.
///
/// **Known limitation, by construction:** a binary older than the release
/// that introduced this rule does not contain the rule, so it cannot warn
/// about itself. The check protects against *future* skew (a project needing
/// 1.5 while the developer runs 1.3), not against every past version — the
/// same shape as npm's `engines` field. That is a real ceiling, not an
/// oversight: nothing a config file says can make an old binary read it.
///
/// Pre-release suffixes on the running version are deliberately ignored, so
/// `1.2.0-dev` satisfies a `1.2.0` floor. Strict semver orders a pre-release
/// *below* its release, which would make every source build of the current
/// tip fail against a floor stamped from that same tip — technically correct
/// and practically useless. A `-dev` build of 1.2.0 has 1.2.0's behavior,
/// which is what the floor is actually asking about.
class ToolchainVersionRule extends Rule {
  const ToolchainVersionRule({this.runningVersion = dialectVersion});

  /// The version of the binary doing the checking. Injectable so the rule
  /// can be tested against floors on both sides without recompiling.
  final String runningVersion;

  @override
  String get name => 'toolchain_version';

  @override
  IssueSeverity get defaultSeverity => IssueSeverity.error;

  @override
  List<Issue> run(DialectProject project) {
    final raw = project.config.extras['toolchain'];
    if (raw is! Map) return const [];
    final declared = raw['min_version'];
    if (declared == null) return const [];

    final floor = _parse(declared.toString());
    final running = _parse(runningVersion);
    // An unparseable version on either side is not this rule's business to
    // adjudicate — staying silent beats inventing a failure from a typo.
    if (floor == null || running == null) return const [];
    if (!_isOlder(running, floor)) return const [];

    return [
      Issue(
        severity: defaultSeverity,
        ruleName: name,
        message:
            'This project requires Dialect ${declared.toString()} or newer, '
            'but the binary on PATH is $runningVersion.',
        file: p.join(project.root, 'dialect', 'dialect.yaml'),
        hint:
            'Upgrade the CLI (see the install steps in the README), then '
            're-run. If the floor is wrong, lower `toolchain.min_version` in '
            'dialect.yaml — but only after checking the newer behavior the '
            'project relies on, since an older binary can silently do the '
            'wrong thing rather than refuse.',
      ),
    ];
  }

  /// `major.minor.patch` as a 3-list, ignoring any `-prerelease` / `+build`
  /// suffix. Returns null when the string isn't a recognizable version.
  static List<int>? _parse(String version) {
    final core = version.trim().split(RegExp(r'[-+]')).first;
    final parts = core.split('.');
    if (parts.isEmpty || parts.length > 3) return null;
    final out = <int>[0, 0, 0];
    for (var i = 0; i < parts.length; i++) {
      final n = int.tryParse(parts[i]);
      if (n == null || n < 0) return null;
      out[i] = n;
    }
    return out;
  }

  static bool _isOlder(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] < b[i];
    }
    return false;
  }
}
