import 'dart:math' as math;

import 'geo.dart';

/// Logical pixels per metre at map [zoom] and [lat]. MapLibre (and therefore
/// `maplibre_gl`) defines zoom on 512 px tiles; 256 px raster-convention zoom
/// is one level higher for the same scale.
double pxPerMetre(double zoom, double lat, {int tileSize = 512}) =>
    tileSize * math.pow(2, zoom) / (equatorM * math.cos(lat * math.pi / 180));

class CellSize {
  const CellSize(this.name, this.widthM);
  final String name;

  /// Equal-area square side in metres (for H3: sqrt of the hexagon area).
  final double widthM;
}

List<Map<String, Object>> pixelTable({
  required List<CellSize> cells,
  required double lat,
  List<int> zooms = const [10, 12, 14, 15, 16, 17, 18, 19, 20],
  double devicePixelRatio = 2.75,
}) => [
  for (final z in zooms)
    {
      'zoom': z,
      for (final c in cells) ...{
        '${c.name}_dp': _round1(c.widthM * pxPerMetre(z.toDouble(), lat)),
        '${c.name}_px': _round1(
          c.widthM * pxPerMetre(z.toDouble(), lat) * devicePixelRatio,
        ),
      },
    },
];

double _round1(double v) => (v * 10).round() / 10;
