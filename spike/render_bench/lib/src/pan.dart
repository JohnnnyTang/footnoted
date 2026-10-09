import 'dart:math' as math;

import 'cells.dart';

// The fixed camera path for the scripted pan: north-up, untilted, 20 s at a
// constant screen speed. It crosses S01-10's home city (Mexico City) west to
// east through its densest walks, then follows the CDMX → Monterrey road-trip
// corridor (spike/tracegen's Highway 57/85 via points).

typedef Waypoint = ({double lat, double lon});

/// The criterion-2 zoom.
const panZoom = 10.0;
const panDuration = Duration(seconds: 20);

const panWaypoints = <Waypoint>[
  (lat: 19.4200, lon: -99.2000), // Chapultepec (west)
  (lat: 19.4150, lon: -99.1500), // Roma / Narvarte
  (lat: 19.4326, lon: -99.1332), // Centro: corridor start
  (lat: 20.5888, lon: -100.3899), // Querétaro
  (lat: 22.1565, lon: -100.9855), // San Luis Potosí
  (lat: 23.6486, lon: -100.6436), // Matehuala
  (lat: 25.4232, lon: -101.0053), // Saltillo
  (lat: 25.6866, lon: -100.3161), // Monterrey
];

/// Share of the path one pass covers at [zoom]. Above z10 it shrinks with the
/// zoom so the screen speed stays that of the z10 pass (z14: the first 1/16,
/// inside Mexico City; z18: the first 1/256, a few hundred metres). At z10
/// and below the whole path is covered.
double pathFraction(double zoom) =>
    zoom <= panZoom ? 1.0 : math.pow(2, panZoom - zoom).toDouble();

final List<(double, double)> _merc = [
  for (final w in panWaypoints) (lonToX(w.lon, 0), latToY(w.lat, 0)),
];

final List<double> _cum = () {
  final out = [0.0];
  for (var i = 1; i < _merc.length; i++) {
    final (ax, ay) = _merc[i - 1];
    final (bx, by) = _merc[i];
    final dx = bx - ax, dy = by - ay;
    out.add(out.last + math.sqrt(dx * dx + dy * dy));
  }
  return out;
}();

/// Path length in z10 512-px tile widths (1 unit = one z10 tile).
double get panLengthTilesZ10 => _cum.last * 1024;

/// Camera target at [t] ∈ [0, 1] of a pass at [zoom]: constant speed in Web
/// Mercator, i.e. constant pixels per second at a fixed zoom.
Waypoint panAt(double t, {double zoom = panZoom}) {
  final d = t.clamp(0.0, 1.0) * pathFraction(zoom) * _cum.last;
  var i = 0;
  while (i < _cum.length - 2 && _cum[i + 1] < d) {
    i++;
  }
  final leg = _cum[i + 1] - _cum[i];
  final u = leg == 0 ? 0.0 : ((d - _cum[i]) / leg).clamp(0.0, 1.0);
  final (ax, ay) = _merc[i];
  final (bx, by) = _merc[i + 1];
  return (
    lat: yToLat(ay + (by - ay) * u, 0),
    lon: xToLon(ax + (bx - ax) * u, 0),
  );
}
