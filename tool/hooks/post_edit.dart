// Claude Code PostToolUse hook (Edit|Write|MultiEdit).
// - *.dart (not generated): runs `dart format` on the file.
// - pubspec.yaml: blocks (exit 2) if a denylisted dependency was declared.
// Fails open: any internal error exits 0 so a broken hook never stalls work.
import 'dart:convert';
import 'dart:io';

import '../guards/denylist.dart';

const _generated = ['.g.dart', '.freezed.dart', '.drift.dart', '.mocks.dart'];

Future<void> main() async {
  try {
    final input = jsonDecode(await stdin.transform(utf8.decoder).join()) as Map;
    final toolInput = (input['tool_input'] as Map?) ?? const {};
    final path = toolInput['file_path'] as String?;
    if (path == null || !File(path).existsSync()) return;

    final name = path.split(RegExp(r'[\\/]')).last;
    if (name == 'pubspec.yaml') {
      final denied = <String>[];
      for (final dep in declaredDependencies(File(path).readAsStringSync())) {
        final reason = denialReason(dep);
        if (reason != null) denied.add('$dep: $reason');
      }
      if (denied.isNotEmpty) {
        stderr.writeln(
          'Blocked by FootNoted invariant guard (tool/guards/denylist.dart). '
          'Remove these dependencies from $path:\n  ${denied.join('\n  ')}',
        );
        exit(2);
      }
      return;
    }

    if (name.endsWith('.dart') && !_generated.any(name.endsWith)) {
      await Process.run(Platform.resolvedExecutable, ['format', path]);
    }
  } catch (_) {
    // Fail open.
  }
}
