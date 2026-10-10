// Desktop probe of the fog's tile query along the pan path: which tiles are
// slow, and how many rows the query visits for them.
//   dart run bin/tile_query_probe.dart --segcells ../out/dataset.segcells.bin \
//       [--layout A|B] [--zoom 10] [--top 8]
// Builds the coverage DB in a temp directory, then times every tile of every
// padded visible set along the path once (cold tile, warm page cache after the
// first touch), and prints the slowest tiles as JSON lines.
import 'dart:convert';
import 'dart:io';

import 'package:render_bench/src/coverage_db.dart';
import 'package:render_bench/src/fog.dart';
import 'package:render_bench/src/pan.dart';
import 'package:sqlite3/sqlite3.dart';

String? _opt(List<String> args, String name) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

void main(List<String> args) {
  final layout = Layout.parse(_opt(args, 'layout'));
  final zoom = double.parse(_opt(args, 'zoom') ?? '10');
  final top = int.parse(_opt(args, 'top') ?? '8');
  final tmp = Directory.systemTemp.createTempSync('tile_probe');
  final path = '${tmp.path}/c.db';
  final build = buildCoverageDb(
    segcellsPath: _opt(args, 'segcells') ?? '../out/dataset.segcells.bin',
    dbPath: path,
    layout: layout,
  );
  stdout.writeln(jsonEncode({'build': build}));
  final db = CoverageDb.open(path, layout);
  final raw = sqlite3.open(path)
    ..execute(
      "PRAGMA key = \"x'2b7e151628aed2a6abf7158809cf4f3c762e7151f4a7c5c6b1a0dbe3b1e6c1f0'\"",
    );
  final level = (zoom.floor() + 6).clamp(0, 20);
  final seen = <TileKey>{};
  final rows = <Map<String, Object>>[];
  for (var s = 0; s <= 600; s++) {
    final w = panAt(s / 600, zoom: zoom);
    for (final t in visibleTiles(
      lat: w.lat,
      lon: w.lon,
      zoom: zoom,
      width: 411,
      height: 914,
    )) {
      if (!seen.add(t)) continue;
      final sw = Stopwatch()..start();
      final cols = db.tileColumns(t.z, t.x, t.y, level);
      final ms = sw.elapsedMicroseconds / 1000;
      final sh = 20 - t.z;
      final y0 = t.y << sh, y1 = ((t.y + 1) << sh) - 1;
      final x0 = t.x << sh, x1 = ((t.x + 1) << sh) - 1;
      final visited = layout == Layout.spans
          ? raw
                    .select(
                      'SELECT count(*) FROM coverage_spans WHERE y BETWEEN ? AND ?',
                      [y0, y1],
                    )
                    .first
                    .values
                    .first
                as int
          : raw
                    .select(
                      'SELECT count(*) FROM cell_coverage WHERE cell_id BETWEEN ? AND ?',
                      [x0 << 20, (x1 << 20) | ((1 << 20) - 1)],
                    )
                    .first
                    .values
                    .first
                as int;
      rows.add({
        'tile': '${t.z}/${t.x}/${t.y}',
        'ms': ms,
        'rows_visited': visited,
        'covered_cells': cols.fold<int>(0, (a, c) => a + c.length),
      });
    }
  }
  rows.sort((a, b) => (b['ms']! as double).compareTo(a['ms']! as double));
  final total = rows.fold<double>(0, (a, r) => a + (r['ms']! as double));
  stdout.writeln(
    jsonEncode({
      'layout': layout.label,
      'zoom': zoom,
      'level': level,
      'tiles': rows.length,
      'total_ms': total,
    }),
  );
  rows.take(top).forEach((r) => stdout.writeln(jsonEncode(r)));
  db.close();
  raw.close();
  tmp.deleteSync(recursive: true);
}
