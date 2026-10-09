// Claude Code SessionStart hook: prints the ACTIVE stage row(s) and that
// stage's latest "Next:" line, so every session starts oriented.
// Output goes into the session context; keep it short. Fails open.
import 'dart:io';

void main(List<String> args) {
  try {
    final root =
        Platform.environment['CLAUDE_PROJECT_DIR'] ?? Directory.current.path;
    final index = File('$root/stages/README.md');
    if (!index.existsSync()) return;

    final active = index
        .readAsLinesSync()
        .where((l) => l.startsWith('|') && l.contains('`ACTIVE'))
        .toList();
    if (active.isEmpty) {
      stdout.writeln('FootNoted: no ACTIVE stage (see stages/README.md).');
      return;
    }
    stdout.writeln('FootNoted — active stage (stages/README.md):');
    for (final row in active) {
      stdout.writeln('  ${row.trim()}');
      final link = RegExp(r'\]\(([^)]+/README\.md)\)')
          .firstMatch(row)
          ?.group(1);
      if (link == null) continue;
      final stageReadme = File('$root/stages/$link');
      if (!stageReadme.existsSync()) continue;
      final next = stageReadme
          .readAsLinesSync()
          .where((l) => l.trimLeft().startsWith('- **Next:**'))
          .lastOrNull;
      if (next != null) stdout.writeln('  ${next.trim()}');
    }
    stdout.writeln(
      'Rules: AGENTS.md. Orchestrating a wave → skill orchestrate-wave; '
      'executing a session brief → skill run-session.',
    );
  } catch (_) {
    // Fail open.
  }
}
