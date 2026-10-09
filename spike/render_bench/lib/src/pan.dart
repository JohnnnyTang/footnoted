// The fixed camera path for the scripted pan: z10, north-up, untilted, linear
// in latitude/longitude between waypoints, 20 s in total. It crosses the stand-in
// home city (Berlin) west to east, then follows the road-trip corridor south
// to Leipzig.

typedef Waypoint = ({double lat, double lon});

const panZoom = 10.0;
const panDuration = Duration(seconds: 20);

const panWaypoints = <Waypoint>[
  (lat: 52.52, lon: 13.05),
  (lat: 52.52, lon: 13.75),
  (lat: 52.40, lon: 13.40),
  (lat: 51.95, lon: 12.95),
  (lat: 51.34, lon: 12.37),
];

/// Camera target at [t] ∈ [0, 1] along the path; each leg gets an equal share
/// of the time.
Waypoint panAt(double t) {
  final legs = panWaypoints.length - 1;
  final f = (t.clamp(0.0, 1.0)) * legs;
  final i = f.floor().clamp(0, legs - 1);
  final u = f - i;
  final a = panWaypoints[i], b = panWaypoints[i + 1];
  return (lat: a.lat + (b.lat - a.lat) * u, lon: a.lon + (b.lon - a.lon) * u);
}
