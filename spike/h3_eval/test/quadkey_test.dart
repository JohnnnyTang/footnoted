import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:h3_eval/src/corridors.dart';
import 'package:h3_eval/src/geo.dart';
import 'package:h3_eval/src/pixel_table.dart';
import 'package:h3_eval/src/quadkey_cover.dart';
import 'package:h3_eval/src/span_set.dart';

List<(int, int)> _cover(double x0, double y0, double x1, double y1) {
  final out = <(int, int)>[];
  supercover(x0, y0, x1, y1, (x, y) => out.add((x, y)));
  return out;
}

void main() {
  group('supercover', () {
    test('horizontal line', () {
      expect(_cover(0.5, 0.5, 3.5, 0.5), [(0, 0), (1, 0), (2, 0), (3, 0)]);
    });

    test('exact corner crossings include both side cells', () {
      final cells = _cover(0.5, 0.5, 2.5, 2.5).toSet();
      expect(cells, {(0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (2, 2)});
    });

    test('random segments: 4-connected, from start cell to end cell', () {
      final rnd = math.Random(1);
      for (var i = 0; i < 500; i++) {
        final p = [for (var k = 0; k < 4; k++) rnd.nextDouble() * 40];
        final cells = _cover(p[0], p[1], p[2], p[3]);
        expect(cells.first, (p[0].floor(), p[1].floor()));
        expect(cells.last, (p[2].floor(), p[3].floor()));
        for (var j = 1; j < cells.length; j++) {
          final d =
              (cells[j].$1 - cells[j - 1].$1).abs() +
              (cells[j].$2 - cells[j - 1].$2).abs();
          expect(d, lessThanOrEqualTo(2));
        }
      }
    });
  });

  group('dilation', () {
    test('a point at the equator, 100 m at z20 → r = 3 disk (29 cells)', () {
      final c = quadkeyCover(const [LatLng(0.0001, 10)], 100, 20);
      expect(c.cells.cellCount, 29);
    });

    test('at 60°N the radius in cells doubles', () {
      final eq = quadkeyCover(const [LatLng(0.0001, 10)], 100, 20);
      final n60 = quadkeyCover(const [LatLng(60, 10)], 100, 20);
      expect(n60.cells.cellCount, greaterThan(eq.cells.cellCount * 3.5));
    });

    test('z21 covers about 4x the cells of z20 and about 2x the spans', () {
      final line = cityWalkLine();
      final a = quadkeyCover(line, 100, 20).cells;
      final b = quadkeyCover(line, 100, 21).cells;
      expect(b.cellCount / a.cellCount, closeTo(4, 0.4));
      expect(b.spanCount / a.spanCount, closeTo(2, 0.3));
    });
  });

  group('SpanSet', () {
    test('fromRaw merges overlapping and adjacent intervals', () {
      final s = SpanSet.fromRaw(4, {
        0: [5, 7, 0, 2, 3, 3],
      });
      expect(s.rows[0], [0, 3, 5, 7]);
      expect(s.cellCount, 7);
      expect(s.spanCount, 2);
      expect(s.contains(7, 0), isTrue);
      expect(s.contains(4, 0), isFalse);
      expect(s.contains(8, 0), isFalse);
    });

    test('toIds packs (x << L) | y, sorted', () {
      final s = SpanSet.fromRaw(4, {
        2: [1, 1],
        1: [3, 3],
      });
      expect(s.toIds(), [(1 << 4) | 2, (3 << 4) | 1]);
    });

    test('compaction: an aligned 4x4 block becomes one cell', () {
      final s = SpanSet.fromRaw(2, {
        for (var y = 0; y < 4; y++) y: [0, 3],
      });
      expect(s.compactedCount(), 1);
      expect(s.compactedCount(minLevel: 1), 4);
    });

    test('compaction: an unaligned 2x2 block does not compact', () {
      final s = SpanSet.fromRaw(3, {
        1: [1, 2],
        2: [1, 2],
      });
      expect(s.compactedCount(), 4);
    });

    test('rollup is "any child covered"', () {
      final s = SpanSet.fromRaw(3, {
        1: [1, 2],
      });
      final r = s.rollup(2);
      expect(r.rows, {
        0: [0, 1],
      });
    });

    test('rectangles: a block is one, an L-shape two', () {
      final block = SpanSet.fromRaw(4, {
        for (var y = 0; y < 3; y++) y: [0, 2],
      });
      expect(block.rectangleCount(), 1);
      final l = SpanSet.fromRaw(4, {
        0: [0, 0],
        1: [0, 0],
        2: [0, 2],
      });
      expect(l.rectangleCount(), 2);
    });

    test('rectangles are split at tile edges', () {
      final s = SpanSet.fromRaw(4, {
        0: [2, 5],
        1: [2, 5],
      });
      final per = s.rectanglesPerTile(2);
      expect(per.values.toList()..sort(), [1, 1]);
    });
  });

  test('capsule vertices sit on the buffer distance', () {
    const a = LatLng(45, 1), b = LatLng(45.03, 1.05);
    final poly = capsule(a, b, 500);
    for (final p in poly) {
      expect(distanceToPolylineM(p, const [a, b]), closeTo(500, 1));
    }
  });

  test('corridor lengths', () {
    expect(polylineLengthM(driveLine()) / 1000, closeTo(1000, 5));
    expect(polylineLengthM(cityWalkLine()), closeTo(5000, 1));
  });

  test('a z20 cell is 512 dp at MapLibre zoom 20 at any latitude', () {
    for (final lat in [0.0, 45.0, 60.0]) {
      expect(cellWidthM(lat, 20) * pxPerMetre(20, lat), closeTo(512, 1e-6));
    }
  });
}
