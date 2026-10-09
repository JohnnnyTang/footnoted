import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:h3_flutter/h3_flutter.dart';

import 'corridors.dart';
import 'geo.dart';
import 'h3_raw.dart';
import 'pixel_table.dart';
import 'quadkey_cover.dart';
import 'span_set.dart';

typedef Emit = void Function(String kind, Map<String, Object?> data);

const quadLevels = [20, 21];
const h3Resolutions = [11, 12];
const timingReps = 3;
const samplesPerCorridor = 20000;

/// cellsToMultiPolygon on 3.4 M res-12 cells took 468 s in run 1; later runs
/// cap it. Raise the cap to measure everything.
const outlineMaxCells = 1000000;

int _medianMs(List<int> v) => (v..sort())[v.length ~/ 2];

(T, int) _timed<T>(T Function() f) {
  final sw = Stopwatch()..start();
  final r = f();
  return (r, sw.elapsedMilliseconds);
}

(T, int, List<int>) _timedMedian<T>(T Function() f, {int reps = timingReps}) {
  late T result;
  final times = <int>[];
  for (var i = 0; i < reps; i++) {
    final (r, ms) = _timed(f);
    result = r;
    times.add(ms);
  }
  return (result, _medianMs(List.of(times)), times);
}

Int64List _sortedUnique(List<int> v) {
  final a = Int64List.fromList(v)..sort();
  var n = 0;
  for (var i = 0; i < a.length; i++) {
    if (n == 0 || a[i] != a[n - 1]) a[n++] = a[i];
  }
  return Int64List.sublistView(a, 0, n);
}

bool _containsSorted(Int64List a, int v) {
  var lo = 0, hi = a.length - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (a[mid] < v) {
      lo = mid + 1;
    } else if (a[mid] > v) {
      hi = mid - 1;
    } else {
      return true;
    }
  }
  return false;
}

class _Sample {
  _Sample(this.p, this.distM);
  final LatLng p;
  final double distM;
}

/// Points scattered uniformly across a ±2·buffer band around the line, each
/// with its exact distance to the polyline. Seeded.
List<_Sample> _samples(Corridor c, int n) {
  final rnd = math.Random(7);
  final line = c.line;
  final cum = <double>[0];
  for (var i = 1; i < line.length; i++) {
    cum.add(cum.last + haversineM(line[i - 1], line[i]));
  }
  final total = cum.last;
  final out = <_Sample>[];
  for (var s = 0; s < n; s++) {
    final at = rnd.nextDouble() * total;
    var i = 1;
    var lo = 1, hi = line.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cum[mid] < at) {
        lo = mid + 1;
      } else {
        i = mid;
        hi = mid - 1;
      }
    }
    final a = line[i - 1], b = line[i];
    final f = LocalFrame(a);
    final (bx, by) = f.toXY(b);
    final len = math.sqrt(bx * bx + by * by);
    final t = len == 0 ? 0.0 : (at - cum[i - 1]) / (cum[i] - cum[i - 1]);
    final off = (rnd.nextDouble() * 4 - 2) * c.bufferM;
    final nx = len == 0 ? 0.0 : -by / len, ny = len == 0 ? 0.0 : bx / len;
    final p = f.toLatLng(t * bx + off * nx, t * by + off * ny);
    final window = line.length > 200
        ? line.sublist(math.max(0, i - 6), math.min(line.length, i + 6))
        : line;
    out.add(_Sample(p, distanceToPolylineM(p, window)));
  }
  return out;
}

/// Boundary error of a cover, as equivalent metres per side of the line:
/// "missed" = inside the buffer but not covered; "over" = covered but between
/// buffer and 2·buffer from the line.
Map<String, Object?> _boundaryError(
  List<_Sample> samples,
  double bufferM,
  bool Function(LatLng) covered,
) {
  var inside = 0, missed = 0, outer = 0, over = 0, beyond = 0;
  for (final s in samples) {
    final c = covered(s.p);
    if (s.distM <= bufferM) {
      inside++;
      if (!c) missed++;
    } else if (s.distM <= 2 * bufferM) {
      outer++;
      if (c) over++;
    } else if (c) {
      beyond++;
    }
  }
  return {
    'samples_inside': inside,
    'samples_outer': outer,
    'missed_m': _r1(missed / inside * bufferM),
    'over_m': _r1(over / outer * bufferM),
    'covered_beyond_2x': beyond,
  };
}

double _r1(double v) => (v * 10).round() / 10;
double _r3(double v) => (v * 1000).round() / 1000;

double _quadAreaM2(SpanSet s) {
  var a = 0.0;
  for (final e in s.rows.entries) {
    final w = cellWidthM(cellRowCenterLat(e.key, s.level), s.level);
    var n = 0;
    final r = e.value;
    for (var i = 0; i < r.length; i += 2) {
      n += r[i + 1] - r[i] + 1;
    }
    a += n * w * w;
  }
  return a;
}

Map<String, Object?> _perTile(SpanSet s, int tileLevel) {
  final per = s.rectanglesPerTile(tileLevel);
  final counts = per.values.toList()..sort();
  final total = counts.fold<int>(0, (a, b) => a + b);
  return {
    'tiles': counts.length,
    'rects_total': total,
    'vertices_total': total * 4,
    'vertices_per_tile_mean': counts.isEmpty
        ? 0
        : (total * 4 / counts.length).round(),
    'vertices_per_tile_p50': counts.isEmpty
        ? 0
        : counts[counts.length ~/ 2] * 4,
    'vertices_per_tile_max': counts.isEmpty ? 0 : counts.last * 4,
  };
}

Future<void> runEvaluation(Emit emit, {required String buildMode}) async {
  emit('env', {
    'os': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'cpus': Platform.numberOfProcessors,
    'dart': Platform.version.split(' ').first,
    'build_mode': buildMode,
  });

  final (h3, loadMs) = _timed(() => const H3Factory().load());
  final raw = H3Raw.open();
  emit('h3_load', {'load_ms': loadMs});

  final hexInfo = <int, Map<String, double>>{};
  for (final res in [...h3Resolutions, 10, 13]) {
    final area = h3.getHexagonAreaAvg(res, H3MetricUnits.m);
    final edge = h3.getHexagonEdgeLengthAvg(res, H3MetricUnits.m);
    hexInfo[res] = {'area_m2': area, 'edge_m': edge};
  }
  emit('h3_resolutions', {
    for (final e in hexInfo.entries)
      'res${e.key}': {
        'area_m2_avg': _r1(e.value['area_m2']!),
        'edge_m_avg': _r1(e.value['edge_m']!),
        'equal_area_side_m': _r1(math.sqrt(e.value['area_m2']!)),
      },
  });

  for (final c in standardCorridors()) {
    final lengthM = polylineLengthM(c.line);
    final samples = _samples(c, samplesPerCorridor);
    final idealAreaM2 =
        lengthM * 2 * c.bufferM + math.pi * c.bufferM * c.bufferM;
    emit('corridor', {
      'corridor': c.name,
      'vertices': c.line.length,
      'length_km': _r3(lengthM / 1000),
      'buffer_m': c.bufferM,
      'ideal_area_km2_no_overlap': _r3(idealAreaM2 / 1e6),
    });

    final z10Tiles = quadkeyCover(c.line, c.bufferM, 20).cells.rollup(10);

    for (final rule in RadiusRule.values) {
      for (final level in quadLevels) {
        final (cover, spansMs, spanTimes) = _timedMedian(
          () => quadkeyCover(c.line, c.bufferM, level, rule: rule),
        );
        final s = cover.cells;
        final (ids, idsMs) = _timed(s.toIds);
        final (compacted, compactMs) = _timed(() => s.compactedCount());
        final (rects, rectsMs) = _timed(s.rectangleCount);
        final (perTile, perTileMs) = _timed(() => _perTile(s, 10));
        final rollups = <String, Object?>{};
        for (final p in [18, 16]) {
          final (r, rollupMs) = _timed(() => s.rollup(p));
          rollups['z$p'] = {
            'cells': r.cellCount,
            'spans': r.spanCount,
            'rollup_ms': rollupMs,
            'rects': r.rectangleCount(),
            'per_z10_tile': _perTile(r, 10),
          };
        }
        emit('quadkey', {
          'corridor': c.name,
          'level': level,
          'radius_rule': rule.name,
          'line_cells': cover.lineCells,
          'cells': s.cellCount,
          'spans': s.spanCount,
          'rows': s.rows.length,
          'cover_to_spans_ms_median': spansMs,
          'cover_to_spans_ms_runs': spanTimes,
          'spans_to_sorted_ids_ms': idsMs,
          'ids_bytes': ids.lengthInBytes,
          'compacted_cells': compacted,
          'compact_ms': compactMs,
        });
        // Android logcat truncates a line at about 1 KB, so emit in parts.
        emit('quadkey_render', {
          'corridor': c.name,
          'level': level,
          'radius_rule': rule.name,
          'rects': rects,
          'rects_ms': rectsMs,
          'per_z10_tile': perTile,
          'per_z10_tile_ms': perTileMs,
        });
        for (final e in rollups.entries) {
          emit('quadkey_rollup', {
            'corridor': c.name,
            'level': level,
            'radius_rule': rule.name,
            'rollup': e.key,
            ...e.value! as Map<String, Object?>,
          });
        }
        emit('quadkey_error', {
          'corridor': c.name,
          'level': level,
          'radius_rule': rule.name,
          'area_km2': _r3(_quadAreaM2(s) / 1e6),
          'boundary_error': _boundaryError(samples, c.bufferM, (p) {
            final x = lonToCellX(p.lon, level).floor();
            final y = latToCellY(p.lat, level).floor();
            return s.contains(x, y);
          }),
        });
      }
    }

    final capsules = [
      for (var i = 1; i < c.line.length; i++)
        capsule(c.line[i - 1], c.line[i], c.bufferM),
    ];

    for (final res in h3Resolutions) {
      final (rawCells, rawMs, rawTimes) = _timedMedian(() {
        final all = <int>[];
        for (final poly in capsules) {
          all.addAll(raw.polygonToCells(poly, res));
        }
        return _sortedUnique(all);
      });
      final (pubCells, pubMs) = _timed(() {
        final all = <int>[];
        for (final poly in capsules) {
          for (final b in h3.polygonToCells(
            perimeter: [for (final p in poly) GeoCoord(lat: p.lat, lon: p.lon)],
            resolution: res,
          )) {
            all.add(b.toInt());
          }
        }
        return _sortedUnique(all);
      });
      final (rawCompact, rawCompactMs) = _timed(
        () => raw.compactCells(rawCells),
      );
      final bigCells = [for (final v in rawCells) BigInt.from(v)];
      final (pubCompact, pubCompactMs) = _timed(
        () => h3.compactCells(bigCells),
      );
      final step = math.max(1, bigCells.length ~/ 2000);
      var areaSum = 0.0, areaN = 0;
      for (var i = 0; i < bigCells.length; i += step) {
        areaSum += h3.cellArea(bigCells[i], H3Units.m);
        areaN++;
      }
      final cellArea = areaSum / areaN;
      final result = <String, Object?>{
        'corridor': c.name,
        'res': res,
        'capsules': capsules.length,
        'cells': rawCells.length,
        'cells_public_api': pubCells.length,
        'cover_ms_raw_ffi_median': rawMs,
        'cover_ms_raw_ffi_runs': rawTimes,
        'cover_ms_public_api': pubMs,
        'compacted_cells': rawCompact.length,
        'compacted_cells_public_api': pubCompact.length,
        'compact_ms_raw_ffi': rawCompactMs,
        'compact_ms_public_api': pubCompactMs,
        'cell_area_m2_sampled_mean': _r1(cellArea),
        'area_km2': _r3(rawCells.length * cellArea / 1e6),
        'vertices_hex_each': rawCells.length * 6,
        'vertices_hex_compacted': rawCompact.length * 6,
        'z10_tiles_crossed': z10Tiles.cellCount,
        'boundary_error': _boundaryError(
          samples,
          c.bufferM,
          (p) => _containsSorted(rawCells, raw.latLngToCell(p, res)),
        ),
      };
      emit('h3', result);

      if (bigCells.length > outlineMaxCells) {
        emit('h3_outline', {
          'corridor': c.name,
          'res': res,
          'skipped': 'cells > outlineMaxCells ($outlineMaxCells)',
        });
        continue;
      }
      final (outline, outlineMs) = _timed(
        () => h3.cellsToMultiPolygon(bigCells),
      );
      var outlineVerts = 0, rings = 0;
      for (final polygon in outline) {
        for (final ring in polygon) {
          rings++;
          outlineVerts += ring.length;
        }
      }
      emit('h3_outline', {
        'corridor': c.name,
        'res': res,
        'polygons': outline.length,
        'rings': rings,
        'outline_vertices': outlineVerts,
        'cells_to_multipolygon_ms': outlineMs,
        'outline_vertices_per_z10_tile_mean':
            (outlineVerts / z10Tiles.cellCount).round(),
      });
    }
  }

  final widths = <CellSize>[
    for (final l in quadLevels) CellSize('z$l', cellWidthM(45, l)),
    for (final r in h3Resolutions)
      CellSize('h3r$r', math.sqrt(hexInfo[r]!['area_m2']!)),
  ];
  emit('pixel_table_45N', {
    'note': 'logical dp per cell edge at MapLibre zoom (512 px tiles); px at DPR 2.75',
    'widths_m': {for (final w in widths) w.name: _r1(w.widthM)},
  });
  for (final row in pixelTable(cells: widths, lat: 45)) {
    emit('pixel_row_45N', row);
  }
  emit('done', {});
}
