import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

// Local stand-in for the footnoted_geo math (S01-10 owns the real one). Cell
// packing follows spike/FORMAT.md §1: id = (x << L) | y.

const int maxLevel = 20;
const double maxLat = 85.05112878;

int packCell(int x, int y, int level) => (x << level) | y;
int cellX(int id, int level) => id >> level;
int cellY(int id, int level) => id & ((1 << level) - 1);

double lonToX(double lon, int level) => (lon + 180.0) / 360.0 * (1 << level);

double latToY(double lat, int level) {
  final clamped = lat.clamp(-maxLat, maxLat);
  final s = math.sin(clamped * math.pi / 180.0);
  return (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * (1 << level);
}

double xToLon(num x, int level) => x / (1 << level) * 360.0 - 180.0;

double yToLat(num y, int level) {
  final n = math.pi * (1 - 2 * y / (1 << level));
  return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180.0 / math.pi;
}

/// Sorts [ids] in place and returns the unique prefix as a view.
Int64List sortUnique(Int64List ids) {
  if (ids.isEmpty) return ids;
  ids.sort();
  var w = 1;
  for (var r = 1; r < ids.length; r++) {
    if (ids[r] != ids[w - 1]) ids[w++] = ids[r];
  }
  return Int64List.sublistView(ids, 0, w);
}

/// Parent IDs of a sorted level-[level] array, one level up, sorted unique.
Int64List rollUp(Int64List ids, int level) {
  final out = Int64List(ids.length);
  final p = level - 1;
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    out[i] = packCell(cellX(id, level) >> 1, cellY(id, level) >> 1, p);
  }
  return Int64List.fromList(sortUnique(out));
}

/// Reads a FORMAT.md §3 `*.cells.bin` (little-endian int64, sorted, unique).
Int64List readCellsBin(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final n = bytes.length ~/ 8;
  final out = Int64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = data.getInt64(i * 8, Endian.little);
  }
  return out;
}

Uint8List encodeCellsBin(Int64List ids) {
  final data = ByteData(ids.length * 8);
  for (var i = 0; i < ids.length; i++) {
    data.setInt64(i * 8, ids[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

int lowerBound(Int64List a, int value, [int lo = 0, int? hi]) {
  var h = hi ?? a.length;
  var l = lo;
  while (l < h) {
    final m = (l + h) >> 1;
    if (a[m] < value) {
      l = m + 1;
    } else {
      h = m;
    }
  }
  return l;
}

/// Covered cells at every level 0..20, built once from the z20 set. The spike's
/// minimal stand-in for rollups (F01.3); production rollups are S01-31's.
class CoverageIndex {
  CoverageIndex._(this.levels);

  final List<Int64List> levels;

  factory CoverageIndex.fromZ20(Int64List z20) {
    final levels = List<Int64List>.filled(maxLevel + 1, Int64List(0));
    levels[maxLevel] = z20;
    for (var l = maxLevel; l > 0; l--) {
      levels[l - 1] = rollUp(levels[l], l);
    }
    return CoverageIndex._(levels);
  }

  int count(int level) => levels[level].length;

  /// Per column of the tile (tz, tx, ty) at [level], the covered row indices
  /// (local to the tile, ascending). Column-major because ids sort by x first.
  List<Int32List> tileColumns(int tz, int tx, int ty, int level) {
    final d = level - tz;
    final side = 1 << d;
    final x0 = tx << d;
    final y0 = ty << d;
    final ids = levels[level];
    final cols = List<Int32List>.filled(side, Int32List(0));
    for (var i = 0; i < side; i++) {
      final x = x0 + i;
      final first = packCell(x, y0, level);
      final lo = lowerBound(ids, first);
      // `+ side`, not `| (y0 + side)`: at the bottom edge y0 + side == 2^level.
      final hi = lowerBound(ids, first + side, lo);
      if (hi == lo) continue;
      final col = Int32List(hi - lo);
      for (var k = lo; k < hi; k++) {
        col[k - lo] = cellY(ids[k], level) - y0;
      }
      cols[i] = col;
    }
    return cols;
  }
}
