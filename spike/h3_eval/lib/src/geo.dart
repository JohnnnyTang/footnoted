import 'dart:math' as math;

const double earthRadiusM = 6378137.0;
const double equatorM = 2 * math.pi * earthRadiusM;
const double maxMercatorLat = 85.05112878;

class LatLng {
  const LatLng(this.lat, this.lon);
  final double lat;
  final double lon;

  @override
  String toString() => 'LatLng($lat, $lon)';
}

double _rad(double d) => d * math.pi / 180;

double haversineM(LatLng a, LatLng b) {
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

double polylineLengthM(List<LatLng> line) {
  var total = 0.0;
  for (var i = 1; i < line.length; i++) {
    total += haversineM(line[i - 1], line[i]);
  }
  return total;
}

/// Equirectangular metres around [origin]; accurate to well under 0.1% over
/// the few kilometres the spike projects at a time.
class LocalFrame {
  LocalFrame(this.origin) : _cosLat = math.cos(_rad(origin.lat));
  final LatLng origin;
  final double _cosLat;

  (double, double) toXY(LatLng p) => (
    _rad(p.lon - origin.lon) * earthRadiusM * _cosLat,
    _rad(p.lat - origin.lat) * earthRadiusM,
  );

  LatLng toLatLng(double x, double y) => LatLng(
    origin.lat + y / earthRadiusM * 180 / math.pi,
    origin.lon + x / (earthRadiusM * _cosLat) * 180 / math.pi,
  );
}

/// Distance in metres from [p] to the polyline, using a frame centred on [p].
double distanceToPolylineM(LatLng p, List<LatLng> line) {
  final f = LocalFrame(p);
  var best = double.infinity;
  var (ax, ay) = f.toXY(line.first);
  if (line.length == 1) return math.sqrt(ax * ax + ay * ay);
  for (var i = 1; i < line.length; i++) {
    final (bx, by) = f.toXY(line[i]);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    final d = math.sqrt(cx * cx + cy * cy);
    if (d < best) best = d;
    ax = bx;
    ay = by;
  }
  return best;
}
