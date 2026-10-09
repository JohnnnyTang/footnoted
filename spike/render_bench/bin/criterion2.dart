// Exit criterion 2 table from measure.dart run directories:
//   dart run bin/criterion2.dart --runs out/runs --device-json device.json \
//       [--out criterion2.md]
// Prints the markdown and, with --out, also writes it.
import 'dart:convert';
import 'dart:io';

import 'package:render_bench/src/criterion.dart';

String? _opt(List<String> args, String name) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

void main(List<String> args) {
  final runsDir = Directory(_opt(args, 'runs') ?? 'out/runs');
  final devicePath = _opt(args, 'device-json');
  final device = devicePath == null
      ? <String, dynamic>{}
      : jsonDecode(File(devicePath).readAsStringSync()) as Map<String, dynamic>;
  final dirs = runsDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final runs = <RunResult>[];
  for (final d in dirs) {
    final s = File('${d.path}/summary.json');
    if (!s.existsSync()) continue;
    final a = File('${d.path}/app_result.json');
    runs.add(
      RunResult.fromJson(
        jsonDecode(s.readAsStringSync()) as Map<String, dynamic>,
        a.existsSync()
            ? jsonDecode(a.readAsStringSync()) as Map<String, dynamic>
            : null,
      ),
    );
  }
  final md = criterion2Markdown(runs, device);
  final out = _opt(args, 'out');
  if (out != null) File(out).writeAsStringSync(md);
  stdout.write(md);
}
