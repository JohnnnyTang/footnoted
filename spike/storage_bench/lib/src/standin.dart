import 'dart:math' as math;
import 'dart:typed_data';

import 'dataset.dart';

// Stand-in corridors (FORMAT.md section 5) until S01-10's dataset merges.
// The local capsule rasteriser below is spike-only; footnoted_geo owns the
// real supercover + per-row dilation.

const double _earthCircumferenceM = 40075016.686;
const double _worldCells = 1048576.0; // 2^20

double _cellX(double lon) => (lon + 180) / 360 * _worldCells;

double _cellY(double lat) {
  final r = lat * math.pi / 180;
  return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) /
      2 *
      _worldCells;
}

double cellWidthM(double lat) =>
    _earthCircumferenceM * math.cos(lat * math.pi / 180) / _worldCells;

class LatLon {
  const LatLon(this.lat, this.lon);
  final double lat;
  final double lon;
}

/// Cells whose centres lie within [bufferM] of the polyline (or of the
/// first and last point only, when [endpointsOnly]).
Int64List rasterise(
  List<LatLon> pts,
  double bufferM, {
  bool endpointsOnly = false,
}) {
  final rows = <int, List<int>>{};
  void capsule(LatLon a, LatLon b) {
    final r = bufferM / cellWidthM((a.lat + b.lat) / 2);
    final ax = _cellX(a.lon), ay = _cellY(a.lat);
    final bx = _cellX(b.lon), by = _cellY(b.lat);
    final dx = bx - ax, dy = by - ay;
    final len = math.sqrt(dx * dx + dy * dy);
    final corners = <List<double>>[];
    if (len > 0) {
      final nx = -dy / len * r, ny = dx / len * r;
      corners.addAll([
        [ax + nx, ay + ny],
        [bx + nx, by + ny],
        [bx - nx, by - ny],
        [ax - nx, ay - ny],
      ]);
    }
    final y0 = (math.min(ay, by) - r).floor();
    final y1 = (math.max(ay, by) + r).ceil();
    for (var y = y0; y <= y1; y++) {
      final c = y + 0.5;
      var lo = double.infinity, hi = double.negativeInfinity;
      for (final p in [
        [ax, ay],
        [bx, by],
      ]) {
        final d = c - p[1];
        if (d.abs() <= r) {
          final w = math.sqrt(r * r - d * d);
          lo = math.min(lo, p[0] - w);
          hi = math.max(hi, p[0] + w);
        }
      }
      for (var i = 0; i < corners.length; i++) {
        final p = corners[i], q = corners[(i + 1) % corners.length];
        if ((p[1] - c) * (q[1] - c) > 0 || p[1] == q[1]) continue;
        final x = p[0] + (c - p[1]) * (q[0] - p[0]) / (q[1] - p[1]);
        lo = math.min(lo, x);
        hi = math.max(hi, x);
      }
      if (lo > hi) continue;
      final xa = (lo - 0.5).ceil(), xb = (hi - 0.5).floor();
      if (xa <= xb) (rows[y] ??= []).addAll([xa, xb]);
    }
  }

  if (endpointsOnly) {
    capsule(pts.first, pts.first);
    capsule(pts.last, pts.last);
  } else if (pts.length == 1) {
    capsule(pts.first, pts.first);
  } else {
    for (var i = 0; i + 1 < pts.length; i++) {
      capsule(pts[i], pts[i + 1]);
    }
  }

  final out = <int>[];
  rows.forEach((y, iv) {
    final pairs = [
      for (var i = 0; i < iv.length; i += 2) [iv[i], iv[i + 1]],
    ]..sort((a, b) => a[0].compareTo(b[0]));
    var cur = pairs.first;
    void emit(List<int> p) {
      for (var x = p[0]; x <= p[1]; x++) {
        out.add(packCell(x, y));
      }
    }

    for (final p in pairs.skip(1)) {
      if (p[0] <= cur[1] + 1) {
        if (p[1] > cur[1]) cur = [cur[0], p[1]];
      } else {
        emit(cur);
        cur = p;
      }
    }
    emit(cur);
  });
  final list = Int64List.fromList(out)..sort();
  return list;
}

LatLon _step(LatLon p, double headingDeg, double distM) {
  final h = headingDeg * math.pi / 180;
  final dLat = distM * math.cos(h) / 111320;
  final dLon = distM * math.sin(h) / (111320 * math.cos(p.lat * math.pi / 180));
  return LatLon(p.lat + dLat, p.lon + dLon);
}

/// Random walk on a street grid of [spacingM] around [centre].
List<LatLon> _gridWalk(
  math.Random rnd,
  LatLon centre,
  double halfSizeM,
  double spacingM,
  double lengthM,
) {
  final n = (halfSizeM / spacingM).floor();
  var gx = rnd.nextInt(2 * n + 1) - n, gy = rnd.nextInt(2 * n + 1) - n;
  LatLon at(int x, int y) =>
      _step(_step(centre, 90, x * spacingM), 0, y * spacingM);
  final pts = [at(gx, gy)];
  var dir = rnd.nextInt(4);
  for (var d = 0.0; d < lengthM; d += spacingM) {
    final turn = rnd.nextInt(10);
    if (turn < 2) dir = (dir + 1) % 4;
    if (turn == 2) dir = (dir + 3) % 4;
    final nx = gx + const [1, 0, -1, 0][dir];
    final ny = gy + const [0, 1, 0, -1][dir];
    if (nx.abs() > n || ny.abs() > n) {
      dir = (dir + 2) % 4;
      continue;
    }
    gx = nx;
    gy = ny;
    pts.add(at(gx, gy));
  }
  return pts;
}

/// A meandering road: a point every [stepM], heading wandering +-15 degrees
/// around [bearingDeg].
List<LatLon> _road(
  math.Random rnd,
  LatLon start,
  double bearingDeg,
  double lengthM, {
  double stepM = 2000,
}) {
  final pts = [start];
  var h = bearingDeg;
  for (var d = 0.0; d < lengthM; d += stepM) {
    h += (rnd.nextDouble() - 0.5) * 30;
    h += (bearingDeg - h) * 0.2;
    pts.add(_step(pts.last, h, stepM));
  }
  return pts;
}

class StandInSpec {
  const StandInSpec({
    this.seed = 42,
    this.homeWalks = 400,
    this.foreignWalks = 30,
    this.flights = 10,
  });

  /// A tiny dataset for tests.
  const StandInSpec.tiny()
    : seed = 7,
      homeWalks = 6,
      foreignWalks = 2,
      flights = 2;

  final int seed;
  final int homeWalks;
  final int foreignWalks;
  final int flights;

  bool get isTiny => homeWalks < 50;
}

/// Deterministic stand-in dataset: a home city (Berlin, 100 m), three foreign
/// stays (100 m), two 50 km road trips and one 1,000 km leg (500 m), and
/// endpoint-only flights (500 m). The long leg runs near 13-20 N (Chennai
/// towards Mumbai), where z20 cells are ~37 m wide, so its row count is
/// comparable with the handoff's ~700 k estimate.
Dataset buildStandIn([StandInSpec spec = const StandInSpec()]) {
  final rnd = math.Random(spec.seed);
  final segs = <Segment>[];
  var id = 0;
  void add(List<LatLon> pts, double buf, String label, {bool ends = false}) {
    segs.add(
      Segment(id++, rasterise(pts, buf, endpointsOnly: ends), label: label),
    );
  }

  const home = LatLon(52.52, 13.405);
  for (var i = 0; i < spec.homeWalks; i++) {
    final len = 2000 + rnd.nextDouble() * 6000;
    add(_gridWalk(rnd, home, 6000, 200, len), 100, 'home walk $i');
  }
  const stays = [
    LatLon(35.68, 139.76),
    LatLon(40.71, -74.0),
    LatLon(-33.92, 18.42),
  ];
  for (final c in stays) {
    for (var i = 0; i < spec.foreignWalks; i++) {
      final len = 2000 + rnd.nextDouble() * 4000;
      add(_gridWalk(rnd, c, 3000, 150, len), 100, 'stay walk');
    }
  }
  final roadLen = spec.isTiny ? 20000.0 : 50000.0;
  add(_road(rnd, home, 200, roadLen), 500, 'road trip south');
  add(_road(rnd, home, 30, roadLen), 500, 'road trip north-east');
  final longLegId = id;
  final legLen = spec.isTiny ? 40000.0 : 1000000.0;
  add(
    _road(rnd, const LatLon(13.08, 80.27), 310, legLen),
    500,
    'road trip 1,000 km',
  );
  const airports = [
    LatLon(52.36, 13.51),
    LatLon(35.55, 139.78),
    LatLon(40.64, -73.78),
    LatLon(-33.97, 18.60),
    LatLon(21.32, -157.92),
  ];
  for (var i = 0; i < spec.flights; i++) {
    final a = airports[i % airports.length];
    final b = airports[(i + 1) % airports.length];
    add([a, b], 500, 'flight $i', ends: true);
  }
  return Dataset(segs, longLegId: longLegId, source: 'stand-in');
}
