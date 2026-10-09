// Time and cell count for a 1,000 km drive with 100 m and 500 m buffers.
// Run from packages/footnoted_geo: dart run benchmark/drive_benchmark.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:footnoted_geo/footnoted_geo.dart';

LatLng _destination(LatLng from, double bearingDeg, double meters) {
  final d = meters / earthRadiusMeters;
  final b = bearingDeg * math.pi / 180;
  final p1 = from.lat * math.pi / 180;
  final l1 = from.lon * math.pi / 180;
  final p2 = math.asin(
    math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(b),
  );
  final l2 =
      l1 +
      math.atan2(
        math.sin(b) * math.sin(d) * math.cos(p1),
        math.cos(d) - math.sin(p1) * math.sin(p2),
      );
  return LatLng(p2 * 180 / math.pi, normalizeLongitude(l2 * 180 / math.pi));
}

/// A drive sampled every [spacing] metres along a great circle.
List<LatLng> _drive(
  LatLng start,
  double bearing,
  double meters,
  double spacing,
) {
  final end = _destination(start, bearing, meters);
  final stepDeg = spacing / earthRadiusMeters * 180 / math.pi;
  return densifyGreatCircle([start, end], maxStepDegrees: stepDeg);
}

int _spans(List<int> ids, int level) {
  final mask = (1 << level) - 1;
  final yx = [for (final id in ids) ((id & mask) << level) | (id >> level)]
    ..sort();
  var spans = 0;
  for (var i = 0; i < yx.length; i++) {
    if (i == 0 ||
        yx[i] != yx[i - 1] + 1 ||
        (yx[i] >> level) != (yx[i - 1] >> level)) {
      spans++;
    }
  }
  return spans;
}

void main(List<String> args) {
  const runs = 5;
  final drives = {
    'equator E-W': _drive(const LatLng(0.5, 10), 90, 1e6, 300),
    '45° E-W': _drive(const LatLng(45, 0), 90, 1e6, 300),
    '45° diagonal': _drive(const LatLng(41, -5), 45, 1e6, 300),
    '19.4°→27.5° (CDMX→N. Laredo)': _drive(
      const LatLng(19.43, -99.13),
      12,
      1e6,
      300,
    ),
    '40°→49° N-S': _drive(const LatLng(40, 5), 0, 1e6, 300),
    '60° E-W': _drive(const LatLng(60, 5), 90, 1e6, 300),
  };
  stdout.writeln(
    '| Drive (1,000 km, fix every 300 m) | Level | Buffer | Line cells | '
    'Dilated cells | Spans | Rasterise ms | Dilate ms |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|');
  for (final MapEntry(key: name, value: points) in drives.entries) {
    for (final level in [20, 21]) {
      for (final buffer in [100.0, 500.0]) {
        var rasterMs = double.infinity;
        var dilateMs = double.infinity;
        late List<int> line;
        late List<int> dilated;
        for (var r = 0; r < runs; r++) {
          final sw = Stopwatch()..start();
          line = rasterizePolyline(points, level: level);
          final t1 = sw.elapsedMicroseconds;
          dilated = dilateCells(line, buffer, level: level);
          final t2 = sw.elapsedMicroseconds;
          rasterMs = math.min(rasterMs, t1 / 1000);
          dilateMs = math.min(dilateMs, (t2 - t1) / 1000);
        }
        stdout.writeln(
          '| $name | z$level | ${buffer.round()} m | ${line.length} | '
          '${dilated.length} | ${_spans(dilated, level)} | '
          '${rasterMs.toStringAsFixed(1)} | ${dilateMs.toStringAsFixed(1)} |',
        );
      }
    }
  }
  stdout.writeln(
    '\nBest of $runs runs; Dart ${Platform.version.split(' ').first} '
    'JIT (dart run), ${Platform.operatingSystem}.',
  );
}
