import 'dart:math' as math;

import 'package:footnoted_geo/footnoted_geo.dart';

import 'model.dart';
import 'rng.dart';

const double _mPerDegLat = 110574;
double _mPerDegLon(double lat) => 111320 * math.cos(lat * math.pi / 180);

/// A local plane around [origin], rotated by [angleDeg] so that a city's
/// street grid runs along the u and v axes. Metres.
class Frame {
  Frame(this.origin, [double angleDeg = 0])
    : _c = math.cos(angleDeg * math.pi / 180),
      _s = math.sin(angleDeg * math.pi / 180);

  final LatLng origin;
  final double _c;
  final double _s;

  (double, double) toUV(LatLng p) {
    final e = (p.lon - origin.lon) * _mPerDegLon(origin.lat);
    final n = (p.lat - origin.lat) * _mPerDegLat;
    return (e * _c + n * _s, -e * _s + n * _c);
  }

  LatLng fromUV(double u, double v) {
    final e = u * _c - v * _s;
    final n = u * _s + v * _c;
    return LatLng(
      origin.lat + n / _mPerDegLat,
      origin.lon + e / _mPerDegLon(origin.lat),
    );
  }
}

LatLng offsetMeters(LatLng p, double east, double north) =>
    LatLng(p.lat + north / _mPerDegLat, p.lon + east / _mPerDegLon(p.lat));

LatLng jitter(Rng rng, LatLng p, double sigmaM) =>
    offsetMeters(p, rng.gaussian() * sigmaM, rng.gaussian() * sigmaM);

/// A street-grid path from [a] to [b]: axis-aligned runs of whole blocks.
List<LatLng> manhattanPath(
  Rng rng,
  Frame frame,
  LatLng a,
  LatLng b, {
  double block = 120,
  int maxBlocks = 8,
}) {
  var (u, v) = frame.toUV(a);
  final (tu, tv) = frame.toUV(b);
  final path = <LatLng>[a];
  var guard = 0;
  while (((tu - u).abs() >= block || (tv - v).abs() >= block) &&
      guard++ < 10000) {
    final du = tu - u;
    final dv = tv - v;
    final alongU = rng.nextDouble() * (du.abs() + dv.abs()) < du.abs();
    final remaining = alongU ? du : dv;
    final step = math.min(
      remaining.abs(),
      (1 + rng.nextInt(maxBlocks)) * block,
    );
    if (alongU) {
      u += step * remaining.sign;
    } else {
      v += step * remaining.sign;
    }
    path.add(frame.fromUV(u, v));
  }
  path.add(b);
  return path;
}

/// A loop from [start] through [stops] random points within [radiusM].
List<LatLng> wanderLoop(
  Rng rng,
  Frame frame,
  LatLng start, {
  required double radiusM,
  int stops = 3,
  double block = 120,
}) {
  final (su, sv) = frame.toUV(start);
  final waypoints = <LatLng>[start];
  for (var i = 0; i < stops; i++) {
    final r = radiusM * math.sqrt(rng.nextDouble());
    final t = rng.nextDouble() * 2 * math.pi;
    waypoints.add(frame.fromUV(su + r * math.cos(t), sv + r * math.sin(t)));
  }
  waypoints.add(start);
  final path = <LatLng>[start];
  for (var i = 1; i < waypoints.length; i++) {
    path.addAll(
      manhattanPath(
        rng,
        frame,
        waypoints[i - 1],
        waypoints[i],
        block: block,
        maxBlocks: 5,
      ).skip(1),
    );
  }
  return path;
}

/// A fixed "road": [via] points joined by sub-waypoints every ~[pieceM]
/// with lateral wiggle up to [wiggleM], so that repeated traversals follow
/// the same curves.
List<LatLng> roadPolyline(
  Rng rng,
  List<LatLng> via, {
  double pieceM = 20000,
  double wiggleM = 2500,
}) {
  final out = <LatLng>[via.first];
  for (var i = 1; i < via.length; i++) {
    final a = via[i - 1];
    final b = via[i];
    final d = greatCircleMeters(a, b);
    final n = math.max(1, (d / pieceM).round());
    final frame = Frame(a);
    final (bu, bv) = frame.toUV(b);
    final len = math.sqrt(bu * bu + bv * bv);
    for (var k = 1; k < n; k++) {
      final t = k / n;
      final w = rng.uniform(-wiggleM, wiggleM);
      out.add(frame.fromUV(bu * t - bv / len * w, bv * t + bu / len * w));
    }
    out.add(b);
  }
  return out;
}

double polylineMeters(List<LatLng> path) {
  var d = 0.0;
  for (var i = 1; i < path.length; i++) {
    d += greatCircleMeters(path[i - 1], path[i]);
  }
  return d;
}

/// Samples [path] every [minM]–[maxM] metres (always both ends) and turns
/// the samples into trace points starting at [startTs], moving at
/// [speedMps]. GPS noise is Gaussian with σ = acc / 2; a [mediaShare] of
/// points are photo anchors (no accuracy, no noise).
List<TracePoint> samplePath(
  Rng rng,
  List<LatLng> path, {
  required int startTs,
  required double speedMps,
  required double minM,
  required double maxM,
  double accMin = 4,
  double accMax = 20,
  double mediaShare = 0,
}) {
  final out = <TracePoint>[];
  var travelled = 0.0;
  var lastTs = startTs - 1;
  void emit(LatLng p) {
    var ts = startTs + (travelled / speedMps * 1000).round();
    if (ts <= lastTs) ts = lastTs + 1;
    lastTs = ts;
    if (rng.chance(mediaShare)) {
      out.add(TracePoint(ts, p.lat, p.lon, null, true));
      return;
    }
    final acc = (rng.uniform(accMin, accMax) * 10).round() / 10;
    final q = jitter(rng, p, acc / 2);
    out.add(TracePoint(ts, q.lat, q.lon, acc, false));
  }

  emit(path.first);
  var next = rng.uniform(minM, maxM);
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1];
    final b = path[i];
    final len = greatCircleMeters(a, b);
    var pos = 0.0;
    while (len - pos >= next) {
      pos += next;
      travelled += next;
      final t = pos / len;
      emit(LatLng(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t));
      next = rng.uniform(minM, maxM);
    }
    next -= len - pos;
    travelled += len - pos;
  }
  emit(path.last);
  return out;
}
