// Copies this package to <dest> as a standalone (non-workspace) package whose
// own pubspec selects SQLCipher through the sqlite3 build hook.
//
// Why: hook user-defines are read only from the workspace root pubspec, which
// is frozen for W1. Inside the workspace this package therefore links upstream
// SQLite (no cipher). The copy runs the same Dart code with SQLCipher.
//
// Usage (from spike/storage_bench):
//   dart run tool/make_standalone.dart <dest> [sqlcipher|sqlite3mc|sqlite3]
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: make_standalone.dart <dest> [source]');
    exit(64);
  }
  final src = Directory.current;
  final dest = Directory(args[0]);
  final source = args.length > 1 ? args[1] : 'sqlcipher';
  const skip = {'build', '.dart_tool', 'out', '.idea'};

  void copy(Directory from, Directory to) {
    to.createSync(recursive: true);
    for (final e in from.listSync(followLinks: false)) {
      final name = e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (e is Directory) {
        if (skip.contains(name)) continue;
        copy(e, Directory('${to.path}/$name'));
      } else if (e is File) {
        e.copySync('${to.path}/$name');
      }
    }
  }

  copy(src, dest);
  final pubspec = File('${dest.path}/pubspec.yaml');
  final lines = pubspec
      .readAsLinesSync()
      .where(
        (l) =>
            l.trim() != 'resolution: workspace' &&
            l.trim() != 'footnoted_geo: any',
      )
      .toList();
  lines.addAll([
    '',
    'hooks:',
    '  user_defines:',
    '    sqlite3:',
    '      source: $source',
  ]);
  pubspec.writeAsStringSync('${lines.join('\n')}\n');
  final lock = File('${src.path}/../../pubspec.lock');
  if (lock.existsSync()) lock.copySync('${dest.path}/pubspec.lock');
  stdout.writeln('standalone copy at ${dest.path} (sqlite3 source: $source)');
  stdout.writeln('next: cd ${dest.path} && flutter pub get');
}
