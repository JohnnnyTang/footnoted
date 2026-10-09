import 'dart:math' as math;

import 'geo.dart';
import 'span_set.dart';

// Spike-local quadkey math. The production version is S01-10's, in
// footnoted_geo; this exists only so the comparison can run in W1.

double lonToCellX(double lon, int level) => (lon + 180) / 360 * (1 << level);

double latToCellY(double lat, int level) {
  final clamped = lat.clamp(-maxMercatorLat, maxMercatorLat);
  final phi = clamped * math.pi / 180;
  final y = (1 - math.log(math.tan(phi) + 1 / math.cos(phi)) / math.pi) / 2;
  return y * (1 << level);
}

double cellRowCenterLat(int y, int level) {
  final n = math.pi * (1 - 2 * (y + 0.5) / (1 << level));
  return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
}

double cellWidthM(double lat, int level) =>
    equatorM * math.cos(lat * math.pi / 180) / (1 << level);

/// Every cell the segment touches (supercover); at an exact corner crossing
/// both side cells are included.
void supercover(
  double x0,
  double y0,
  double x1,
  double y1,
  void Function(int x, int y) emit,
) {
  var cx = x0.floor(), cy = y0.floor();
  final ex = x1.floor(), ey = y1.floor();
  final dx = x1 - x0, dy = y1 - y0;
  final sx = dx > 0 ? 1 : (dx < 0 ? -1 : 0);
  final sy = dy > 0 ? 1 : (dy < 0 ? -1 : 0);
  final tDeltaX = sx == 0 ? double.infinity : 1 / dx.abs();
  final tDeltaY = sy == 0 ? double.infinity : 1 / dy.abs();
  var tMaxX = sx == 0
      ? double.infinity
      : (sx > 0 ? cx + 1 - x0 : x0 - cx) * tDeltaX;
  var tMaxY = sy == 0
      ? double.infinity
      : (sy > 0 ? cy + 1 - y0 : y0 - cy) * tDeltaY;
  emit(cx, cy);
  var guard = (ex - cx).abs() + (ey - cy).abs() + 2;
  while ((cx != ex || cy != ey) && guard-- > 0) {
    if ((tMaxX - tMaxY).abs() < 1e-12) {
      emit(cx + sx, cy);
      emit(cx, cy + sy);
      cx += sx;
      cy += sy;
      tMaxX += tDeltaX;
      tMaxY += tDeltaY;
    } else if (tMaxX < tMaxY) {
      cx += sx;
      tMaxX += tDeltaX;
    } else {
      cy += sy;
      tMaxY += tDeltaY;
    }
    emit(cx, cy);
  }
}

/// `ceil`: handoff "Revealing cells" step 3, r = ceil(buffer / cell width)
/// cells, mask dx² + dy² ≤ r². `exact`: mask dx² + dy² ≤ (buffer / width)²,
/// i.e. a cell is in if its centre is within the buffer of the line cell's
/// centre.
enum RadiusRule { ceil, exact }

class _Dilator {
  _Dilator(this.level, this.bufferM, this.rule);

  final int level;
  final double bufferM;
  final RadiusRule rule;
  final raw = <int, List<int>>{};
  final _halfWidthsByRow = <int, List<int>>{};
  int lineCells = 0;
  int? _lastX, _lastY;

  // Radius is per row, from that row's latitude (F01.6).
  List<int> halfWidths(int y) => _halfWidthsByRow.putIfAbsent(y, () {
    final rr = bufferM / cellWidthM(cellRowCenterLat(y, level), level);
    final r = rule == RadiusRule.ceil ? rr.ceilToDouble() : rr;
    return [
      for (var dy = 0; dy <= r.floor(); dy++)
        math.sqrt(r * r - dy * dy).floor(),
    ];
  });

  void add(int x, int y) {
    if (x == _lastX && y == _lastY) return;
    _lastX = x;
    _lastY = y;
    lineCells++;
    final hw = halfWidths(y);
    final r = hw.length - 1;
    for (var dy = -r; dy <= r; dy++) {
      final h = hw[dy.abs()];
      _stamp(y + dy, x - h, x + h);
    }
  }

  void _stamp(int row, int a, int b) {
    final list = raw[row];
    if (list == null) {
      raw[row] = [a, b];
      return;
    }
    final n = list.length;
    final la = list[n - 2], lb = list[n - 1];
    if (a <= lb + 1 && b >= la - 1) {
      if (a < la) list[n - 2] = a;
      if (b > lb) list[n - 1] = b;
    } else {
      list.addAll([a, b]);
    }
  }
}

class QuadCover {
  QuadCover(this.cells, this.lineCells);
  final SpanSet cells;
  final int lineCells;
}

/// Rasterise the polyline (straight in Mercator between vertices) and dilate
/// by [bufferM].
QuadCover quadkeyCover(
  List<LatLng> line,
  double bufferM,
  int level, {
  RadiusRule rule = RadiusRule.ceil,
}) {
  final d = _Dilator(level, bufferM, rule);
  final xs = [for (final p in line) lonToCellX(p.lon, level)];
  final ys = [for (final p in line) latToCellY(p.lat, level)];
  if (line.length == 1) {
    d.add(xs[0].floor(), ys[0].floor());
  }
  for (var i = 1; i < line.length; i++) {
    supercover(xs[i - 1], ys[i - 1], xs[i], ys[i], d.add);
  }
  return QuadCover(SpanSet.fromRaw(level, d.raw), d.lineCells);
}
