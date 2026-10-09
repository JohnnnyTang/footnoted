import 'dart:math' as math;

import 'geo.dart';

class Corridor {
  const Corridor(this.name, this.line, this.bufferM);
  final String name;
  final List<LatLng> line;
  final double bufferM;
}

/// About 1,000 km eastwards from Bordeaux at ~45°N, a vertex every ~5 km,
/// meandering ±1.5° of latitude so that rows and columns both change.
List<LatLng> driveLine({double targetM = 1000000, double stepM = 5000}) {
  const start = LatLng(44.84, -0.58);
  final out = <LatLng>[start];
  var total = 0.0;
  var lon = start.lon;
  while (total < targetM) {
    final lat = out.last.lat;
    lon +=
        stepM / (earthRadiusM * math.cos(lat * math.pi / 180)) * 180 / math.pi;
    final nextLat = start.lat + 1.5 * math.sin((lon - start.lon) / 3.0);
    final next = LatLng(nextLat, lon);
    total += haversineM(out.last, next);
    out.add(next);
  }
  return out;
}

/// A deterministic 5 km street-grid walk in central Paris: legs of 60–250 m
/// with right-angle turns (seeded).
List<LatLng> cityWalkLine({double targetM = 5000, int seed = 42}) {
  final rnd = math.Random(seed);
  final frame = LocalFrame(const LatLng(48.8566, 2.3522));
  var x = 0.0, y = 0.0, heading = 0;
  final out = [frame.toLatLng(x, y)];
  var total = 0.0;
  while (total < targetM) {
    var leg = 60 + rnd.nextDouble() * 190;
    if (total + leg > targetM) leg = targetM - total;
    final a = heading * math.pi / 2 + 0.3;
    x += leg * math.cos(a);
    y += leg * math.sin(a);
    out.add(frame.toLatLng(x, y));
    total += leg;
    heading = (heading + (rnd.nextBool() ? 1 : 3)) % 4;
    if (rnd.nextDouble() < 0.4) heading = (heading + 3) % 4;
  }
  return out;
}

List<Corridor> standardCorridors() => [
  Corridor('walk_5km_100m', cityWalkLine(), 100),
  Corridor('drive_1000km_500m', driveLine(), 500),
];

/// Polygon of all points within [bufferM] of segment a→b ("capsule"), with
/// [arcSteps] chords per semicircular cap.
List<LatLng> capsule(LatLng a, LatLng b, double bufferM, {int arcSteps = 16}) {
  final f = LocalFrame(a);
  final (bx, by) = f.toXY(b);
  final len = math.sqrt(bx * bx + by * by);
  final base = len == 0 ? 0.0 : math.atan2(by, bx);
  final out = <LatLng>[];
  // Cap around b from +90° to -90° relative to the heading, then around a.
  for (var i = 0; i <= arcSteps; i++) {
    final t = base + math.pi / 2 - math.pi * i / arcSteps;
    out.add(f.toLatLng(bx + bufferM * math.cos(t), by + bufferM * math.sin(t)));
  }
  for (var i = 0; i <= arcSteps; i++) {
    final t = base - math.pi / 2 - math.pi * i / arcSteps;
    out.add(f.toLatLng(bufferM * math.cos(t), bufferM * math.sin(t)));
  }
  return out;
}
