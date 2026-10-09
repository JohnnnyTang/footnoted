// Markdown table of every run under out/runs (or the directory given):
//   dart run bin/summarize.dart [out/runs]
// The SurfaceFlinger column is the app's Flutter SurfaceView (BLAST) layer:
// the frames that reach the screen.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'out/runs' : args.first);
  final dirs = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  stdout.writeln(
    '| run | view | fog | pass | SF median fps | SF % >32 ms | SF frames '
    '| Flutter median fps | Flutter % >32 ms | raster p50/p90 ms '
    '| fog updates | set p50/max ms |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|---|---|');
  for (final d in dirs) {
    final f = File('${d.path}/summary.json');
    final a = File('${d.path}/app_result.json');
    if (!f.existsSync() || !a.existsSync()) continue;
    final s = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final app = jsonDecode(a.readAsStringSync()) as Map<String, dynamic>;
    final appPasses = {
      for (final p in app['passes'] as List) '${p['pass']}': p,
    };
    final view = s['texture'] == true ? 'TextureView' : 'GLSurfaceView/VD';
    final fog = s['fog'] == true ? '${s['strategy']}' : 'off';
    (s['passes'] as Map<String, dynamic>).forEach((n, p) {
      final sf = (p['surfaceflinger'] as Map<String, dynamic>).entries
          .where((e) => e.key.contains('(BLAST)'))
          .map((e) => e.value as Map<String, dynamic>)
          .firstOrNull;
      final ap = appPasses[n] as Map<String, dynamic>;
      final fl = ap['flutter_frames'] as Map<String, dynamic>;
      final r = ap['flutter_raster'] as Map<String, dynamic>;
      final u = ap['fog_updates'] as Map<String, dynamic>;
      final set = u['set'] as Map<String, dynamic>;
      stdout.writeln(
        '| ${d.path.split(RegExp(r'[\\/]')).last.substring(11, 17)} '
        '| $view | $fog | $n '
        '| ${sf?['median_fps'] ?? '–'} | ${sf?['pct_over_32ms'] ?? '–'} '
        '| ${sf?['frames'] ?? '–'} '
        '| ${fl['median_fps']} | ${fl['pct_over_32ms']} '
        '| ${r['p50_ms']}/${r['p90_ms']} '
        '| ${u['n']} | ${set['p50_ms']}/${set['max_ms']} |',
      );
    });
  }
}
