import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:render_bench/src/cells.dart';
import 'package:render_bench/src/fog.dart';
import 'package:render_bench/src/merge.dart';
import 'package:render_bench/src/pan.dart';
import 'package:render_bench/src/standin.dart';

Set<(int, int)> _cellsOf(List<CellRect> rects) {
  final out = <(int, int)>{};
  for (final r in rects) {
    for (var x = r.x0; x < r.x1; x++) {
      for (var y = r.y0; y < r.y1; y++) {
        expect(out.add((x, y)), isTrue, reason: 'rectangles overlap at $x,$y');
      }
    }
  }
  return out;
}

void main() {
  test('lon/lat round-trips through tile coordinates', () {
    for (final (lat, lon) in [(0.0, 0.0), (60.0, 13.4), (-33.9, 151.2)]) {
      expect(xToLon(lonToX(lon, 20), 20), closeTo(lon, 1e-9));
      expect(yToLat(latToY(lat, 20), 20), closeTo(lat, 1e-9));
    }
  });

  test('columnRuns and its complement', () {
    final rows = Int32List.fromList([0, 1, 2, 5, 7, 8]);
    expect(columnRuns(rows, 10), [0, 3, 5, 6, 7, 9]);
    expect(columnRuns(rows, 10, invert: true), [3, 5, 6, 7, 9, 10]);
    expect(columnRuns(Int32List(0), 4, invert: true), [0, 4]);
  });

  test('scanline merge covers exactly the cells, without overlap', () {
    final rnd = math.Random(7);
    for (var trial = 0; trial < 50; trial++) {
      const side = 32;
      final cols = List.generate(side, (_) {
        final rows = [
          for (var y = 0; y < side; y++)
            if (rnd.nextDouble() < 0.4) y,
        ];
        return Int32List.fromList(rows);
      });
      final want = {
        for (var x = 0; x < side; x++)
          for (final y in cols[x]) (x, y),
      };
      expect(_cellsOf(mergeColumns(cols, side)), want);
      final all = {
        for (var x = 0; x < side; x++)
          for (var y = 0; y < side; y++) (x, y),
      };
      expect(
        _cellsOf(mergeColumns(cols, side, invert: true)),
        all.difference(want),
      );
    }
  });

  test('identical runs in adjacent columns merge into one rectangle', () {
    final col = Int32List.fromList([2, 3, 4]);
    expect(mergeColumns([col, col, col, Int32List(0)], 8), [
      const CellRect(0, 2, 3, 5),
    ]);
  });

  test('tileColumns reads the bottom row of an odd column', () {
    // Level 4, tile z0: x = 3 (odd), y = 15 (last row). A bound built with
    // `|` instead of `+` would miss it.
    final z20 = Int64List.fromList([
      packCell(3 << 16, 15 << 16, 20),
      packCell(4 << 16, 0, 20),
    ]);
    final index = CoverageIndex.fromZ20(z20);
    final cols = index.tileColumns(0, 0, 0, 4);
    expect(cols[3], [15]);
    expect(cols[4], [0]);
    expect(index.count(0), 1);
  });

  test('fog tile: empty, full and partial', () {
    // One z20 cell inside every level-3 cell of the z1 tile (0, 0).
    final full = <int>[
      for (var x = 0; x < 4; x++)
        for (var y = 0; y < 4; y++) packCell(x << 17, y << 17, 20),
    ]..sort();
    final index = CoverageIndex.fromZ20(Int64List.fromList(full));
    final fog = FogBuilder(index, detail: 2);
    final stats = FogStats();

    final covered = fog.build(FogStrategy.holes, [(z: 1, x: 0, y: 0)], stats);
    expect(covered['features'], isEmpty);
    final inverse = fog.build(FogStrategy.inverse, [(z: 1, x: 0, y: 0)], stats);
    expect(inverse['features'], isEmpty);

    // At z1 the tile (1, 1) holds no cells: one outer ring, no holes.
    final empty = fog.build(FogStrategy.holes, [(z: 1, x: 1, y: 1)], stats);
    final geometry =
        ((empty['features'] as List).single as Map)['geometry'] as Map;
    expect((geometry['coordinates'] as List).length, 1);
    expect(stats.rects, 0);
  });

  test('visible tiles at z10 cover the viewport plus padding', () {
    final w = panWaypoints.first;
    final core = visibleTiles(
      lat: w.lat,
      lon: w.lon,
      zoom: 10,
      width: 411,
      height: 914,
      pad: 0,
    );
    final padded = visibleTiles(
      lat: w.lat,
      lon: w.lon,
      zoom: 10,
      width: 411,
      height: 914,
    );
    expect(core.length, inInclusiveRange(2, 6));
    expect(padded.toSet().containsAll(core), isTrue);
    expect(padded.every((t) => t.z == 10), isTrue);
  });

  test('stand-in is deterministic and near one million z20 cells', () {
    final a = generateStandIn();
    final b = generateStandIn();
    expect(a, b);
    expect(a.length, inInclusiveRange(700000, 1300000));
    for (var i = 1; i < a.length; i++) {
      if (a[i] <= a[i - 1]) fail('not sorted unique at $i');
    }
  });
}
