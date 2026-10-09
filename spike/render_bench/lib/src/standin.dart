import 'dart:math' as math;
import 'dart:typed_data';

import 'cells.dart';

// Stand-in z20 dump for before S01-10's dataset lands (FORMAT.md §5): a dense
// home city plus one long road-trip corridor, deterministic from the seed.

const standInHome = (lat: 52.5200, lon: 13.4050); // Berlin
const standInCorridor = [
  (lat: 52.5200, lon: 13.4050), // Berlin
  (lat: 51.3397, lon: 12.3731), // Leipzig
  (lat: 49.4521, lon: 11.0767), // Nuremberg
  (lat: 48.1351, lon: 11.5820), // Munich
  (lat: 47.2692, lon: 11.4041), // Innsbruck
  (lat: 45.4384, lon: 10.9916), // Verona
  (lat: 44.4949, lon: 11.3426), // Bologna
  (lat: 43.7696, lon: 11.2558), // Florence
];

class StandInParams {
  const StandInParams({
    this.seed = 42,
    this.cityBufferM = 100,
    this.corridorBufferM = 150,
    this.blockM = 180,
    this.cityRadiusM = 11000,
    this.destinations = 260,
    this.commutes = 1400,
    this.walks = 420,
  });

  final int seed;
  final double cityBufferM, corridorBufferM, blockM, cityRadiusM;
  final int destinations, commutes, walks;

  Map<String, Object> toJson() => {
    'seed': seed,
    'city_buffer_m': cityBufferM,
    'corridor_buffer_m': corridorBufferM,
    'block_m': blockM,
    'city_radius_m': cityRadiusM,
    'destinations': destinations,
    'commutes': commutes,
    'walks': walks,
  };
}

double cellWidthM(double lat) =>
    40075016.686 * math.cos(lat * math.pi / 180) / (1 << maxLevel);

class _Accumulator {
  Int64List _buf = Int64List(1 << 22);
  int _n = 0;

  void add(int id) {
    if (_n == _buf.length) _compact();
    _buf[_n++] = id;
  }

  void _compact() {
    final unique = sortUnique(Int64List.sublistView(_buf, 0, _n));
    _n = unique.length;
    if (_n > _buf.length ~/ 2) {
      final bigger = Int64List(_buf.length * 2)..setRange(0, _n, unique);
      _buf = bigger;
    }
  }

  Int64List finish() {
    _compact();
    return Int64List.fromList(Int64List.sublistView(_buf, 0, _n));
  }
}

List<(int, int)> _disk(double radius) {
  final r = radius.ceil();
  final out = <(int, int)>[];
  for (var dy = -r; dy <= r; dy++) {
    for (var dx = -r; dx <= r; dx++) {
      if (dx * dx + dy * dy <= radius * radius) out.add((dx, dy));
    }
  }
  return out;
}

void _stampLine(
  _Accumulator acc,
  List<(int, int)> disk,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final steps = math.max(1, math.max((bx - ax).abs(), (by - ay).abs()).ceil());
  for (var s = 0; s <= steps; s++) {
    final t = s / steps;
    final cx = (ax + (bx - ax) * t).round();
    final cy = (ay + (by - ay) * t).round();
    for (final (dx, dy) in disk) {
      acc.add(packCell(cx + dx, cy + dy, maxLevel));
    }
  }
}

Int64List generateStandIn([StandInParams p = const StandInParams()]) {
  final rnd = math.Random(p.seed);
  final acc = _Accumulator();

  final hx = lonToX(standInHome.lon, maxLevel);
  final hy = latToY(standInHome.lat, maxLevel);
  final cw = cellWidthM(standInHome.lat);
  final block = p.blockM / cw;
  final cityDisk = _disk(p.cityBufferM / cw);
  final gridR = (p.cityRadiusM / p.blockM).round();

  // Destinations cluster towards the centre, like a real home range.
  (int, int) randomNode() {
    final r = gridR * math.pow(rnd.nextDouble(), 1.6);
    final a = rnd.nextDouble() * 2 * math.pi;
    return ((r * math.cos(a)).round(), (r * math.sin(a)).round());
  }

  final nodes = List.generate(p.destinations, (_) => randomNode());
  void walkGrid(int i0, int j0, int i1, int j1) {
    var i = i0, j = j0;
    while (i != i1 || j != j1) {
      final horizontal = j == j1 || (i != i1 && rnd.nextBool());
      final len = 1 + rnd.nextInt(5);
      var ni = i, nj = j;
      if (horizontal) {
        ni = i + (i1 > i ? 1 : -1) * math.min(len, (i1 - i).abs());
      } else {
        nj = j + (j1 > j ? 1 : -1) * math.min(len, (j1 - j).abs());
      }
      _stampLine(
        acc,
        cityDisk,
        hx + i * block,
        hy + j * block,
        hx + ni * block,
        hy + nj * block,
      );
      i = ni;
      j = nj;
    }
  }

  for (var c = 0; c < p.commutes; c++) {
    final a = nodes[rnd.nextInt(math.min(12, nodes.length))];
    final b = nodes[rnd.nextInt(nodes.length)];
    walkGrid(a.$1, a.$2, b.$1, b.$2);
  }
  for (var w = 0; w < p.walks; w++) {
    final start = nodes[rnd.nextInt(nodes.length)];
    var (i, j) = start;
    final legs = 6 + rnd.nextInt(20);
    for (var k = 0; k < legs; k++) {
      final ni = i + rnd.nextInt(7) - 3;
      final nj = j + rnd.nextInt(7) - 3;
      walkGrid(i, j, ni, nj);
      i = ni;
      j = nj;
    }
  }

  for (var k = 0; k + 1 < standInCorridor.length; k++) {
    final a = standInCorridor[k], b = standInCorridor[k + 1];
    final disk = _disk(p.corridorBufferM / cellWidthM((a.lat + b.lat) / 2));
    _stampLine(
      acc,
      disk,
      lonToX(a.lon, maxLevel),
      latToY(a.lat, maxLevel),
      lonToX(b.lon, maxLevel),
      latToY(b.lat, maxLevel),
    );
  }
  return acc.finish();
}
