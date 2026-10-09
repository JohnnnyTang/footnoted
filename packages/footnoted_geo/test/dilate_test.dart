import 'dart:math' as math;

import 'package:footnoted_geo/footnoted_geo.dart';
import 'package:test/test.dart';

/// Stamps a disk around every source cell, one cell at a time.
Set<int> _naiveDilate(List<int> cells, double buffer, int level) {
  final n = tilesPerAxis(level);
  final out = <int>{};
  for (final id in cells) {
    final x = cellX(id, level);
    final y = cellY(id, level);
    final r = dilationRadiusCells(buffer, y, level);
    for (var dy = -r; dy <= r; dy++) {
      final ty = y + dy;
      if (ty < 0 || ty >= n) continue;
      for (var dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy <= r * r) {
          out.add((((x + dx) % n) << level) | ty);
        }
      }
    }
  }
  return out;
}

void _expectSortedUnique(List<int> ids) {
  for (var i = 1; i < ids.length; i++) {
    expect(ids[i], greaterThan(ids[i - 1]));
  }
}

Map<int, int> _rowWidths(List<int> ids) {
  final widths = <int, int>{};
  for (final id in ids) {
    widths.update(cellY(id), (v) => v + 1, ifAbsent: () => 1);
  }
  return widths;
}

void main() {
  group('radius', () {
    test('100 m is 3 cells at the equator and 6 at 60° (about 2×)', () {
      expect(dilationRadiusCells(100, latToTileY(0.001, 20)), 3);
      expect(dilationRadiusCells(100, latToTileY(60, 20)), 6);
      expect(dilationRadiusCells(500, latToTileY(0.001, 20)), 14);
      expect(dilationRadiusCells(500, latToTileY(60, 20)), 27);
      expect(dilationRadiusCells(0, 0), 0);
    });

    test('disk half-widths', () {
      expect(diskHalfWidths(0), [0]);
      expect(diskHalfWidths(3), [3, 2, 2, 0]);
      expect(diskHalfWidths(5), [5, 4, 4, 4, 3, 0]);
    });
  });

  group('a point reveals a disk', () {
    for (final (name, lat, r) in [('equator', 0.001, 3), ('60°', 60.0, 6)]) {
      test(name, () {
        final p = LatLng(lat, 10);
        final cells = rasterizePolyline([p, p]);
        expect(cells, hasLength(1));
        final disk = dilateCells(cells, 100);
        _expectSortedUnique(disk);
        final hw = diskHalfWidths(r);
        var expected = 2 * hw[0] + 1;
        for (var dy = 1; dy <= r; dy++) {
          expected += 2 * (2 * hw[dy] + 1);
        }
        expect(disk.length, expected);
        expect(disk, contains(cells.single));

        // Every cell centre within 100 m of the source centre is revealed,
        // and nothing beyond 100 m plus a cell diagonal is.
        final c = CellId(cells.single);
        final w = c.widthMeters;
        for (var dx = -r - 1; dx <= r + 1; dx++) {
          for (var dy = -r - 1; dy <= r + 1; dy++) {
            final id = packCell(c.x + dx, c.y + dy);
            final d = greatCircleMeters(c.center, CellId(id).center);
            if (d <= 100) expect(disk, contains(id));
            if (disk.contains(id)) {
              expect(d, lessThanOrEqualTo(100 + w * math.sqrt2));
            }
          }
        }
      });
    }

    test('the disk at 60° has about 4× the cells of the equator disk', () {
      final a = dilateCells(rasterizePolyline(const [LatLng(0.001, 0)]), 100);
      final b = dilateCells(rasterizePolyline(const [LatLng(60, 0)]), 100);
      expect(b.length / a.length, closeTo(4, 0.6));
    });

    test('zero or negative buffer returns the input, sorted and unique', () {
      expect(dilateCells([5, 3, 5], 0), [3, 5]);
      expect(dilateCells([], 100), isEmpty);
    });
  });

  group('per-row radius (F01.6)', () {
    test('a north-south leg widens from equator to 60°', () {
      final line = rasterizePolyline(const [LatLng(0, 10), LatLng(60.5, 10)]);
      final dilated = dilateCells(line, 500);
      final widths = _rowWidths(dilated);
      expect(widths[latToTileY(0.5, 20)], inInclusiveRange(29, 31));
      expect(widths[latToTileY(60, 20)], inInclusiveRange(55, 57));
    });
  });

  group('matches naive stamping', () {
    test('random clusters, including the antimeridian and the poles', () {
      final rnd = math.Random(11);
      for (final level in [20, 21]) {
        final n = tilesPerAxis(level);
        for (var trial = 0; trial < 40; trial++) {
          final cx = switch (trial % 4) {
            0 => 0,
            1 => n - 1,
            _ => rnd.nextInt(n),
          };
          final cy = switch (trial % 5) {
            0 => 0,
            1 => n - 1,
            _ => rnd.nextInt(n),
          };
          final cells = <int>[
            for (var k = 0; k < 12; k++)
              packCell(
                (cx + rnd.nextInt(40) - 20) % n,
                (cy + rnd.nextInt(40) - 20).clamp(0, n - 1),
                level,
              ),
          ];
          // Polar cells are ~3 m wide, so the naive stamp gets expensive.
          final buffer = trial % 5 < 2
              ? [25.0, 100.0][trial % 2]
              : [25.0, 100.0, 500.0][trial % 3];
          final got = dilateCells(cells, buffer, level: level);
          _expectSortedUnique(got);
          // Compare as sorted lists: set equality in package:matcher is
          // quadratic.
          expect(got, _naiveDilate(cells, buffer, level).toList()..sort());
        }
      }
    });
  });

  group('antimeridian and poles', () {
    test('a cell at x = 0 spills into the last column', () {
      final n = tilesPerAxis(20);
      final cells = dilateCells([packCell(0, latToTileY(0.001, 20))], 100);
      final xs = cells.map((id) => cellX(id)).toSet();
      expect(xs, containsAll([0, 1, 2, 3, n - 1, n - 2, n - 3]));
      expect(xs.length, 7);
    });

    test('dilation at the north edge drops rows above the world', () {
      final cells = dilateCells([packCell(500, 0)], 100);
      final ys = cells.map((id) => cellY(id));
      expect(ys.reduce(math.min), 0);
      // About 3.3 m cells at 85.05°: radius ceil(100 / 3.3) = 31.
      expect(ys.reduce(math.max), dilationRadiusCells(100, 0));
      expect(dilationRadiusCells(100, 0), 31);
    });
  });

  group('property: dilate(rasterize(line)) ⊇ rasterize(line)', () {
    test('random lines worldwide', () {
      final rnd = math.Random(3);
      for (var i = 0; i < 200; i++) {
        final lat = (rnd.nextDouble() * 2 - 1) * 88;
        final lon = (rnd.nextDouble() * 2 - 1) * 180;
        final points = [
          LatLng(lat, lon),
          LatLng(
            (lat + (rnd.nextDouble() - 0.5) * 0.05).clamp(-89.0, 89.0),
            normalizeLongitude(lon + (rnd.nextDouble() - 0.5) * 0.05),
          ),
        ];
        final line = rasterizePolyline(points);
        final buffer = [0.0, 25.0, 100.0, 500.0][i % 4];
        final dilated = dilateCells(line, buffer).toSet();
        expect(dilated.containsAll(line), isTrue);
        expect(dilated.length, greaterThanOrEqualTo(line.length));
      }
    });
  });
}
