import 'package:footnoted_geo/footnoted_geo.dart';

enum SegmentKind { local, transit }

enum Reveal { line, endpoints }

class TracePoint {
  TracePoint(this.ts, double lat, double lon, this.acc, this.media)
    : lat = _round7(lat),
      lon = _round7(normalizeLongitude(lon));

  final int ts;

  /// Rounded to 1e-7° as written to the trace, so that the cells are built
  /// from exactly what a reader of the trace sees.
  final double lat;
  final double lon;
  final double? acc;
  final bool media;

  LatLng get latLng => LatLng(lat, lon);

  static double _round7(double v) => (v * 1e7).round() / 1e7;
}

class Segment {
  Segment({
    required this.kind,
    required this.mode,
    required this.bufferM,
    required this.reveal,
    required this.label,
    required this.category,
    required this.points,
  });

  int id = -1;
  final SegmentKind kind;
  final JoinMode mode;
  final double bufferM;
  final Reveal reveal;
  final String label;

  /// Scenario bucket for the stats (home, road, flight, stay).
  final String category;
  final List<TracePoint> points;

  int get startTs => points.first.ts;
  int get endTs => points.last.ts;
}
