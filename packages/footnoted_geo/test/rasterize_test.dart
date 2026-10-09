import 'dart:math' as math;

import 'package:footnoted_geo/footnoted_geo.dart';
import 'package:test/test.dart';

/// Whether the pixel segment p→q meets cell (cx, cy) of size s: [open]
/// requires the open cell interior, otherwise the closed square suffices.
bool _meets(int px, int py, int qx, int qy, int cx, int cy, int s, bool open) {
  var lo = double.negativeInfinity;
  var hi = double.infinity;
  for (final (p, d, a, b) in [
    (px, qx - px, cx * s, (cx + 1) * s),
    (py, qy - py, cy * s, (cy + 1) * s),
  ]) {
    if (d == 0) {
      final inside = open ? (p > a && p < b) : (p >= a && p <= b);
      if (!inside) return false;
      continue;
    }
    final t0 = (a - p) / d;
    final t1 = (b - p) / d;
    lo = math.max(lo, math.min(t0, t1));
    hi = math.min(hi, math.max(t0, t1));
  }
  return open ? lo < hi && lo < 1 && hi > 0 : lo <= hi && lo <= 1 && hi >= 0;
}

Set<(int, int)> _cover(int x0, int y0, int x1, int y1, int shift) {
  final cells = <(int, int)>{};
  supercoverPixels(
    x0,
    y0,
    x1,
    y1,
    (x, y) => cells.add((x, y)),
    cellShift: shift,
  );
  return cells;
}

void main() {
  group('supercover', () {
    test('matches a brute-force reference on random segments', () {
      const shift = 4;
      const s = 1 << shift;
      final rnd = math.Random(7);
      for (var i = 0; i < 3000; i++) {
        // Snap some coordinates to cell boundaries to hit corner cases.
        int c() => rnd.nextBool() ? rnd.nextInt(12) * s : rnd.nextInt(12 * s);
        final x0 = c(), y0 = c(), x1 = c(), y1 = c();
        final got = _cover(x0, y0, x1, y1, shift);
        for (var cx = -1; cx <= 13; cx++) {
          for (var cy = -1; cy <= 13; cy++) {
            final isEnd =
                (cx, cy) == (x0 >> shift, y0 >> shift) ||
                (cx, cy) == (x1 >> shift, y1 >> shift);
            if (isEnd || _meets(x0, y0, x1, y1, cx, cy, s, true)) {
              expect(
                got,
                contains((cx, cy)),
                reason: 'missing ($cx,$cy) for $x0,$y0→$x1,$y1',
              );
            }
            if (got.contains((cx, cy))) {
              expect(
                _meets(x0, y0, x1, y1, cx, cy, s, false),
                isTrue,
                reason: 'extra ($cx,$cy) for $x0,$y0→$x1,$y1',
              );
            }
          }
        }
      }
    });

    test('is thicker than Bresenham on a diagonal through corners', () {
      final cells = _cover(0, 0, 4 * 256, 4 * 256, 8);
      // The four diagonal cells, the end cell (4,4) touched at its corner,
      // and both side cells at every corner crossing.
      expect(cells.length, 13);
      expect(cells, containsAll([(1, 0), (0, 1), (3, 4), (4, 3)]));
    });

    test('a shallow line visits every column', () {
      final cells = _cover(10, 10, 256 * 50 + 3, 300, 8);
      final xs = cells.map((c) => c.$1).toSet();
      expect(xs.length, 51);
    });
  });

  group('rasterizePolyline', () {
    test('equator: an east-west kilometre is one row of ~29 cells', () {
      final cells = rasterizePolyline(const [
        LatLng(0.001, 0),
        LatLng(0.001, 0.01),
      ]);
      final ys = cells.map((id) => cellY(id)).toSet();
      expect(ys.length, 1);
      // 0.01° = 1113 m at 38.2 m per cell.
      expect(cells.length, inInclusiveRange(29, 31));
    });

    test('60°: the same length spans about twice as many cells', () {
      final at60 = rasterizePolyline(const [LatLng(60, 0), LatLng(60, 0.02)]);
      final at0 = rasterizePolyline(const [
        LatLng(0.001, 0),
        LatLng(0.001, 0.02),
      ]);
      // Equal longitude span: equal cell count along a parallel.
      expect(at60.length, closeTo(at0.length, 1));
      // Equal ground length: about 2× the cells at 60°.
      final ground60 = rasterizePolyline(const [
        LatLng(60, 0),
        LatLng(60, 0.04),
      ]);
      expect(ground60.length / at0.length, closeTo(2, 0.1));
    });

    test('output is sorted and unique', () {
      final cells = rasterizePolyline(const [
        LatLng(19.43, -99.13),
        LatLng(19.44, -99.12),
        LatLng(19.43, -99.13),
        LatLng(19.45, -99.14),
      ]);
      for (var i = 1; i < cells.length; i++) {
        expect(cells[i], greaterThan(cells[i - 1]));
      }
    });

    test('a zero-length segment and a single point give one cell', () {
      const p = LatLng(35.6812, 139.7671);
      expect(rasterizePolyline(const [p]), [CellId.fromLatLng(p).value]);
      expect(rasterizePolyline(const [p, p]), [CellId.fromLatLng(p).value]);
      expect(rasterizePolyline(const []), isEmpty);
    });

    test('|lat| > 84°: rows clamp to the world edge', () {
      final cells = rasterizePolyline(const [
        LatLng(84.5, 10),
        LatLng(89.9, 10),
      ]);
      final x = lonToTileX(10, 20);
      final top = latToTileY(84.5, 20);
      expect(cells.map((id) => cellX(id)).toSet(), {x});
      expect(cells.length, top + 1);
      expect(cells.map((id) => cellY(id)).reduce(math.min), 0);

      final south = rasterizePolyline(const [
        LatLng(-84.2, -60),
        LatLng(-90, -60.5),
      ]);
      final n = tilesPerAxis(20);
      expect(south.map((id) => cellY(id)).reduce(math.max), n - 1);
    });
  });

  group('antimeridian', () {
    final n = tilesPerAxis(20);

    test('a short straight leg across ±180° is split, not drawn round', () {
      final cells = rasterizePolyline(const [
        LatLng(21, 179.995),
        LatLng(21, -179.995),
      ]);
      expect(cells.length, inInclusiveRange(29, 31));
      final xs = cells.map((id) => cellX(id)).toSet();
      expect(xs, contains(0));
      expect(xs, contains(n - 1));
      expect(xs.every((x) => x < 20 || x > n - 20), isTrue);
    });

    test('a 20° leg across ±180° stays on the short side', () {
      final cells = rasterizePolyline(const [LatLng(0, 170), LatLng(0, -170)]);
      final xs = cells.map((id) => cellX(id)).toSet();
      expect(xs.every((x) => x <= n ~/ 18 + 1 || x >= n - n ~/ 18 - 1), isTrue);
      expect(cells.length, closeTo(n / 18, 3));
    });

    test('great circle Tokyo → Honolulu never crosses the prime meridian', () {
      const tokyo = LatLng(35.5494, 139.7798);
      const honolulu = LatLng(21.3245, -157.9251);
      final path = densifyGreatCircle(const [tokyo, honolulu]);
      for (final p in path) {
        expect(p.lon >= 139.7 || p.lon <= -157.9, isTrue, reason: '$p');
        expect(p.lon, inInclusiveRange(-180, 180));
      }
      // The arc bulges north of both endpoints.
      expect(path.map((p) => p.lat).reduce(math.max), greaterThan(tokyo.lat));

      final cells = rasterizePolyline(const [
        tokyo,
        honolulu,
      ], mode: JoinMode.greatCircle);
      final xTokyo = lonToTileX(tokyo.lon, 20);
      final xHonolulu = lonToTileX(honolulu.lon, 20);
      for (final id in cells) {
        final x = cellX(id);
        expect(x >= xTokyo || x <= xHonolulu, isTrue);
      }
    });
  });

  group('great-circle densifier', () {
    test('no sub-arc exceeds the step', () {
      const a = LatLng(40.6413, -73.7781); // JFK
      const b = LatLng(51.4700, -0.4543); // LHR
      for (final step in [0.05, 0.5, 2.0]) {
        final path = densifyGreatCircle(const [a, b], maxStepDegrees: step);
        expect(path.first, a);
        expect(path.last, b);
        for (var i = 1; i < path.length; i++) {
          final deg = centralAngle(path[i - 1], path[i]) * 180 / math.pi;
          expect(deg, lessThanOrEqualTo(step + 1e-9));
        }
      }
    });

    test('an arc over the pole is handled', () {
      final path = densifyGreatCircle(const [LatLng(80, 0), LatLng(80, 180)]);
      expect(path.map((p) => p.lat).reduce(math.max), closeTo(90, 0.1));
      for (var i = 1; i < path.length; i++) {
        expect(
          centralAngle(path[i - 1], path[i]) * 180 / math.pi,
          lessThanOrEqualTo(0.1 + 1e-9),
        );
      }
      final cells = rasterizePolyline(const [
        LatLng(80, 0),
        LatLng(80, 180),
      ], mode: JoinMode.greatCircle);
      expect(cells.map((id) => cellY(id)).reduce(math.min), 0);
    });

    test('antipodal points are rejected', () {
      expect(
        () => densifyGreatCircle(const [LatLng(0, 0), LatLng(0, 180)]),
        throwsArgumentError,
      );
    });

    test('points along a meridian stay on it', () {
      final path = densifyGreatCircle(const [LatLng(-10, 25), LatLng(50, 25)]);
      for (final p in path) {
        expect(p.lon, closeTo(25, 1e-9));
      }
      expect(
        greatCircleMeters(path.first, path.last),
        closeTo(60 * math.pi / 180 * earthRadiusMeters, 1e-3),
      );
    });
  });
}
