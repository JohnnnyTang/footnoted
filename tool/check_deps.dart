// CI guard for invariants 1 and 10: fails if any resolved package (direct or
// transitive, read from the workspace pubspec.lock) is denylisted.
// S01-42 extends this with a licence allowlist.
//
// Usage: dart tool/check_deps.dart [path/to/pubspec.lock]
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'guards/denylist.dart';

void main(List<String> args) {
  final lockPath = args.isNotEmpty ? args.first : 'pubspec.lock';
  final lockFile = File(lockPath);
  if (!lockFile.existsSync()) {
    stderr.writeln(
      'check_deps: $lockPath not found; run `flutter pub get` first.',
    );
    exit(2);
  }
  final lock = loadYaml(lockFile.readAsStringSync()) as YamlMap;
  final packages = (lock['packages'] as YamlMap?)?.keys.cast<String>() ?? [];

  final violations = <String>[];
  for (final name in packages) {
    final reason = denialReason(name);
    if (reason != null) violations.add('  $name: $reason');
  }

  if (violations.isEmpty) {
    stdout.writeln('check_deps: ${packages.length} packages, none denylisted.');
    return;
  }
  stderr
    ..writeln('check_deps: denylisted packages found:')
    ..writeln(violations.join('\n'));
  exit(1);
}
