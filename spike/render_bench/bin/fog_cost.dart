// Desktop cost of building and serialising the fog along the pan path, no
// map involved:
//   dart run bin/fog_cost.dart [path/to/x.cells.bin]
// Without a path it uses the stand-in. Prints one JSON line per configuration.
import 'dart:convert';
import 'dart:io';

import 'package:render_bench/src/cells.dart';
import 'package:render_bench/src/fog.dart';
import 'package:render_bench/src/pan.dart';
import 'package:render_bench/src/standin.dart';
import 'package:render_bench/src/stats.dart';

// A 1080 × 2400 px phone at 2.625 dpr.
const _w = 411.0, _h = 914.0;

void main(List<String> args) {
  final sw = Stopwatch()..start();
  final z20 = args.isEmpty ? generateStandIn() : readCellsBin(File(args.first));
  final loadMs = sw.elapsedMilliseconds;
  final index = CoverageIndex.fromZ20(z20);
  stdout.writeln(
    jsonEncode({
      'z20_cells': z20.length,
      'load_ms': loadMs,
      'rollup_ms': sw.elapsedMilliseconds - loadMs,
      'cells_by_level': {
        for (final l in [8, 10, 12, 14, 16, 18, 20]) '$l': index.count(l),
      },
    }),
  );

  for (final zoom in [8.0, 10.0, 12.0, 14.0, 16.0]) {
    for (final detail in [5, 6, 7]) {
      for (final strategy in FogStrategy.values) {
        final fog = FogBuilder(index, detail: detail);
        final build = <double>[], encode = <double>[];
        var maxRects = 0, maxPositions = 0, maxBytes = 0, updates = 0;
        Set<TileKey> shown = {};
        // 600 samples ≈ one per frame of a 20 s pan at 30 fps.
        for (var s = 0; s <= 600; s++) {
          final w = panAt(s / 600);
          final core = visibleTiles(
            lat: w.lat,
            lon: w.lon,
            zoom: zoom,
            width: _w,
            height: _h,
            pad: 0,
          );
          if (shown.containsAll(core)) continue;
          final tiles = visibleTiles(
            lat: w.lat,
            lon: w.lon,
            zoom: zoom,
            width: _w,
            height: _h,
          );
          final stats = FogStats();
          final geojson = fog.build(strategy, tiles, stats);
          final e = Stopwatch()..start();
          final bytes = utf8.encode(jsonEncode(geojson)).length;
          encode.add(e.elapsedMicroseconds / 1000);
          build.add(stats.buildMs);
          updates++;
          shown = tiles.toSet();
          if (stats.rects > maxRects) maxRects = stats.rects;
          if (stats.positions > maxPositions) maxPositions = stats.positions;
          if (bytes > maxBytes) maxBytes = bytes;
        }
        stdout.writeln(
          jsonEncode({
            'zoom': zoom,
            'detail': detail,
            'level': fog.levelFor(zoom.floor()),
            'strategy': strategy.name,
            'updates': updates,
            'build': durationStats(build),
            'encode': durationStats(encode),
            'max_rects': maxRects,
            'max_positions': maxPositions,
            'max_bytes': maxBytes,
          }),
        );
      }
    }
  }
}
