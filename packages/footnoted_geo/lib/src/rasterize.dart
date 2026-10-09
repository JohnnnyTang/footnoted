import 'dart:math' as math;
import 'dart:typed_data';

import 'tile_math.dart';

/// How consecutive points of a polyline are joined.
enum JoinMode {
  /// A straight line in Web Mercator space.
  straight,

  /// The shorter great-circle arc, densified and then drawn as [straight].
  greatCircle,
}

const double defaultGreatCircleStepDegrees = 0.1;

/// Visits every cell that the pixel segment `(x0, y0) → (x1, y1)` passes
/// through (a supercover): at an exact corner crossing both side cells are
/// visited too. Pixels are integers at `cellShift` bits below the cell grid.
/// `x` is not wrapped here, so callers may pass an unwrapped `x1` outside
/// the world and reduce the visited `cx` modulo the world width.
void supercoverPixels(
  int x0,
  int y0,
  int x1,
  int y1,
  void Function(int cx, int cy) visit, {
  int cellShift = tilePixelShift,
}) {
  final s = 1 << cellShift;
  var cx = x0 >> cellShift;
  var cy = y0 >> cellShift;
  final ex = x1 >> cellShift;
  final ey = y1 >> cellShift;
  visit(cx, cy);

  final dx = (x1 - x0).abs();
  final dy = (y1 - y0).abs();
  final sx = x1 > x0 ? 1 : -1;
  final sy = y1 > y0 ? 1 : -1;
  // Distance along each axis from the start to the next cell boundary.
  var bx = sx > 0 ? ((cx + 1) << cellShift) - x0 : x0 - (cx << cellShift);
  var by = sy > 0 ? ((cy + 1) << cellShift) - y0 : y0 - (cy << cellShift);
  var n = (ex - cx).abs() + (ey - cy).abs();

  while (n > 0) {
    if (dy == 0) {
      cx += sx;
      n -= 1;
    } else if (dx == 0) {
      cy += sy;
      n -= 1;
    } else {
      // Compare bx/dx with by/dy without division.
      final tx = bx * dy;
      final ty = by * dx;
      if (tx < ty) {
        cx += sx;
        bx += s;
        n -= 1;
      } else if (ty < tx) {
        cy += sy;
        by += s;
        n -= 1;
      } else {
        visit(cx + sx, cy);
        visit(cx, cy + sy);
        cx += sx;
        cy += sy;
        bx += s;
        by += s;
        n -= 2;
      }
    }
    visit(cx, cy);
  }
}

/// Unit vector of [p] on the sphere.
(double, double, double) _toVector(LatLng p) {
  final phi = p.lat * math.pi / 180;
  final lambda = p.lon * math.pi / 180;
  final c = math.cos(phi);
  return (c * math.cos(lambda), c * math.sin(lambda), math.sin(phi));
}

LatLng _fromVector(double x, double y, double z) {
  final lat = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
  final lon = math.atan2(y, x) * 180 / math.pi;
  return LatLng(lat, normalizeLongitude(lon));
}

/// Central angle between [a] and [b] in radians (numerically stable for
/// both tiny and near-antipodal separations).
double centralAngle(LatLng a, LatLng b) {
  final (ax, ay, az) = _toVector(a);
  final (bx, by, bz) = _toVector(b);
  final cx = ay * bz - az * by;
  final cy = az * bx - ax * bz;
  final cz = ax * by - ay * bx;
  final cross = math.sqrt(cx * cx + cy * cy + cz * cz);
  final dot = ax * bx + ay * by + az * bz;
  return math.atan2(cross, dot);
}

/// Great-circle distance in metres on the WGS84-equatorial-radius sphere.
double greatCircleMeters(LatLng a, LatLng b) =>
    centralAngle(a, b) * earthRadiusMeters;

/// Inserts points along the great-circle arc between each pair of
/// consecutive [points] so that no sub-arc exceeds [maxStepDegrees].
/// Longitudes of the output are in [-180, 180). Throws [ArgumentError] for
/// an antipodal pair, whose arc is undefined.
List<LatLng> densifyGreatCircle(
  List<LatLng> points, {
  double maxStepDegrees = defaultGreatCircleStepDegrees,
}) {
  if (maxStepDegrees <= 0) {
    throw ArgumentError.value(maxStepDegrees, 'maxStepDegrees', 'must be > 0');
  }
  if (points.length < 2) return List.of(points);
  final step = maxStepDegrees * math.pi / 180;
  final out = <LatLng>[points.first];
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final omega = centralAngle(a, b);
    if (math.pi - omega < 1e-9) {
      throw ArgumentError(
        'antipodal points have no unique great circle: $a, $b',
      );
    }
    final n = (omega / step).ceil();
    if (n > 1) {
      final (ax, ay, az) = _toVector(a);
      final (bx, by, bz) = _toVector(b);
      final sinOmega = math.sin(omega);
      for (var k = 1; k < n; k++) {
        final t = k / n;
        final wa = math.sin((1 - t) * omega) / sinOmega;
        final wb = math.sin(t * omega) / sinOmega;
        out.add(
          _fromVector(wa * ax + wb * bx, wa * ay + wb * by, wa * az + wb * bz),
        );
      }
    }
    out.add(b);
  }
  return out;
}

/// The cells at [level] touched by [points] joined with [mode], as sorted
/// unique IDs. A single point (or a zero-length leg) gives its one cell.
/// A leg whose longitudes differ by more than 180° crosses the antimeridian;
/// it is drawn the short way, wrapping at ±180°, never the long way round.
Int64List rasterizePolyline(
  List<LatLng> points, {
  JoinMode mode = JoinMode.straight,
  int level = cellLevel,
  double maxStepDegrees = defaultGreatCircleStepDegrees,
}) {
  if (points.isEmpty) return Int64List(0);
  final path = mode == JoinMode.greatCircle
      ? densifyGreatCircle(points, maxStepDegrees: maxStepDegrees)
      : points;
  final world = worldPixels(level);
  final tiles = tilesPerAxis(level);
  final ids = <int>[];
  void visit(int cx, int cy) => ids.add(((cx % tiles) << level) | cy);

  var px = lonToPixelX(path.first.lon, level);
  var py = latToPixelY(path.first.lat, level);
  visit(px >> tilePixelShift, py >> tilePixelShift);
  for (var i = 1; i < path.length; i++) {
    final qx = lonToPixelX(path[i].lon, level);
    final qy = latToPixelY(path[i].lat, level);
    var ux = qx;
    final d = qx - px;
    if (d > world ~/ 2) {
      ux -= world;
    } else if (d < -(world ~/ 2)) {
      ux += world;
    }
    supercoverPixels(px, py, ux, qy, visit);
    px = qx;
    py = qy;
  }
  return sortedUnique(ids);
}

/// Sorts [ids] and drops duplicates.
Int64List sortedUnique(List<int> ids) {
  final sorted = Int64List.fromList(ids)..sort();
  if (sorted.isEmpty) return sorted;
  var w = 1;
  for (var r = 1; r < sorted.length; r++) {
    if (sorted[r] != sorted[w - 1]) sorted[w++] = sorted[r];
  }
  return w == sorted.length ? sorted : Int64List.sublistView(sorted, 0, w);
}
