import 'dart:math' as math;
import 'dart:typed_data';

import 'cells.dart';
import 'coverage_source.dart';
import 'merge.dart';

enum FogStrategy {
  /// (a) Per visible tile, one polygon: the tile with the merged covered
  /// rectangles as holes.
  holes,

  /// (b) Per visible tile, the merged **uncovered** rectangles as a
  /// MultiPolygon with no holes.
  inverse,
}

typedef TileKey = ({int z, int x, int y});

/// Tiles (at the integer zoom the fog is built for) that cover a north-up,
/// untilted viewport of [width] × [height] logical pixels, plus [pad] tiles on
/// every side. MapLibre zoom z draws the world 512 · 2^z px wide.
List<TileKey> visibleTiles({
  required double lat,
  required double lon,
  required double zoom,
  required double width,
  required double height,
  int pad = 1,
}) {
  final tz = zoom.floor().clamp(0, maxLevel);
  final tilePx = 512 * math.pow(2, zoom - tz);
  final cx = lonToX(lon, tz), cy = latToY(lat, tz);
  final hw = width / 2 / tilePx, hh = height / 2 / tilePx;
  final n = 1 << tz;
  final out = <TileKey>[];
  final yMin = math.max(0, (cy - hh).floor() - pad);
  final yMax = math.min(n - 1, (cy + hh).floor() + pad);
  final xMin = math.max(0, (cx - hw).floor() - pad);
  final xMax = math.min(n - 1, (cx + hw).floor() + pad);
  for (var y = yMin; y <= yMax; y++) {
    for (var x = xMin; x <= xMax; x++) {
      out.add((z: tz, x: x, y: y));
    }
  }
  return out;
}

class FogStats {
  int tiles = 0;
  int cacheHits = 0;
  int queried = 0;
  int rects = 0;
  int positions = 0;
  int level = 0;

  /// Geometry (merge + rings) on the calling isolate.
  double buildMs = 0;

  /// Time spent inside the coverage source's tile queries.
  double queryMs = 0;

  /// Wall time from asking the source to having every tile's cells, which
  /// adds the isolate hop to [queryMs].
  double waitMs = 0;

  Map<String, Object> toJson() => {
    'tiles': tiles,
    'cache_hits': cacheHits,
    'queried': queried,
    'rects': rects,
    'positions': positions,
    'level': level,
    'build_ms': buildMs,
    'query_ms': queryMs,
    'wait_ms': waitMs,
  };
}

class _TileFog {
  _TileFog(this.feature, this.rects, this.positions);
  final Map<String, Object>? feature;
  final int rects, positions;
}

/// Builds the fog FeatureCollection for a set of tiles, caching each tile's
/// feature by (strategy, tile, level). Tiles not in the cache are fetched from
/// the [source] in one batch. The spike's stand-in for S01-41.
class FogBuilder {
  FogBuilder(this.source, {this.detail = 6});

  final CoverageSource source;

  /// Cell level = tile zoom + [detail]; at detail 6 a cell is 8 logical px.
  int detail;

  final _cache = <(FogStrategy, int, int, int, int), _TileFog>{};

  int levelFor(int tz) => math.min(maxLevel, tz + detail);

  void clearCache() => _cache.clear();

  Future<Map<String, Object>> build(
    FogStrategy strategy,
    List<TileKey> tiles,
    FogStats stats,
  ) async {
    stats
      ..tiles = tiles.length
      ..cacheHits = 0
      ..queried = 0
      ..rects = 0
      ..positions = 0;
    final missing = <TileKey>[];
    for (final t in tiles) {
      final level = levelFor(t.z);
      stats.level = level;
      if (_cache.containsKey((strategy, t.z, t.x, t.y, level))) {
        stats.cacheHits++;
      } else {
        missing.add(t);
      }
    }
    final wait = Stopwatch()..start();
    final fetched = missing.isEmpty
        ? null
        : await source.columns([
            for (final t in missing)
              (z: t.z, x: t.x, y: t.y, level: levelFor(t.z)),
          ]);
    stats
      ..waitMs = wait.elapsedMicroseconds / 1000
      ..queryMs = fetched?.queryMs ?? 0
      ..queried = missing.length;

    final sw = Stopwatch()..start();
    for (var i = 0; i < missing.length; i++) {
      final t = missing[i];
      final level = levelFor(t.z);
      _cache[(strategy, t.z, t.x, t.y, level)] = _tile(
        strategy,
        t,
        level,
        fetched!.columns[i],
      );
    }
    final features = <Map<String, Object>>[];
    for (final t in tiles) {
      final fog = _cache[(strategy, t.z, t.x, t.y, levelFor(t.z))]!;
      stats
        ..rects += fog.rects
        ..positions += fog.positions;
      if (fog.feature != null) features.add(fog.feature!);
    }
    stats.buildMs = sw.elapsedMicroseconds / 1000;
    return {'type': 'FeatureCollection', 'features': features};
  }

  _TileFog _tile(
    FogStrategy strategy,
    TileKey t,
    int level,
    List<Int32List> cols,
  ) {
    final d = level - t.z;
    final side = 1 << d;
    final x0 = t.x << d, y0 = t.y << d;
    final lons = List<double>.generate(
      side + 1,
      (i) => _round(xToLon(x0 + i, level)),
    );
    final lats = List<double>.generate(
      side + 1,
      (i) => _round(yToLat(y0 + i, level)),
    );
    List<List<double>> ring(CellRect r, {required bool ccw}) {
      final w = lons[r.x0], e = lons[r.x1], n = lats[r.y0], s = lats[r.y1];
      return ccw
          ? [
              [w, s],
              [e, s],
              [e, n],
              [w, n],
              [w, s],
            ]
          : [
              [w, s],
              [w, n],
              [e, n],
              [e, s],
              [w, s],
            ];
    }

    switch (strategy) {
      case FogStrategy.holes:
        final covered = mergeColumns(cols, side);
        if (covered.length == 1 && covered.first.area == side * side) {
          return _TileFog(null, 1, 0);
        }
        final rings = [
          ring(CellRect(0, 0, side, side), ccw: true),
          for (final r in covered) ring(r, ccw: false),
        ];
        return _TileFog(
          {
            'type': 'Feature',
            'properties': <String, Object>{},
            'geometry': {'type': 'Polygon', 'coordinates': rings},
          },
          covered.length,
          rings.length * 5,
        );
      case FogStrategy.inverse:
        final uncovered = mergeColumns(cols, side, invert: true);
        if (uncovered.isEmpty) return _TileFog(null, 0, 0);
        return _TileFog(
          {
            'type': 'Feature',
            'properties': <String, Object>{},
            'geometry': {
              'type': 'MultiPolygon',
              'coordinates': [
                for (final r in uncovered) [ring(r, ccw: true)],
              ],
            },
          },
          uncovered.length,
          uncovered.length * 5,
        );
    }
  }
}

double _round(double v) => (v * 1e6).roundToDouble() / 1e6;
