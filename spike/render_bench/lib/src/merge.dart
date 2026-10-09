import 'dart:typed_data';

/// A half-open rectangle of cells in tile-local coordinates.
class CellRect {
  const CellRect(this.x0, this.y0, this.x1, this.y1);

  final int x0, y0, x1, y1;

  int get area => (x1 - x0) * (y1 - y0);

  @override
  bool operator ==(Object other) =>
      other is CellRect &&
      other.x0 == x0 &&
      other.y0 == y0 &&
      other.x1 == x1 &&
      other.y1 == y1;

  @override
  int get hashCode => Object.hash(x0, y0, x1, y1);

  @override
  String toString() => 'CellRect($x0,$y0,$x1,$y1)';
}

/// Vertical runs `[start, end)` of one column, flattened as start,end pairs.
/// With [invert], the runs of the complement within `[0, side)`.
List<int> columnRuns(Int32List rows, int side, {bool invert = false}) {
  final runs = <int>[];
  var i = 0;
  if (!invert) {
    while (i < rows.length) {
      final start = rows[i];
      var end = start + 1;
      i++;
      while (i < rows.length && rows[i] == end) {
        end++;
        i++;
      }
      runs
        ..add(start)
        ..add(end);
    }
    return runs;
  }
  var y = 0;
  while (i < rows.length) {
    if (rows[i] > y) {
      runs
        ..add(y)
        ..add(rows[i]);
    }
    y = rows[i] + 1;
    i++;
  }
  if (y < side) {
    runs
      ..add(y)
      ..add(side);
  }
  return runs;
}

/// Scanline merge: column runs with identical extents in adjacent columns grow
/// into one rectangle. Rectangles never overlap, and their union is exactly the
/// covered (or, with [invert], uncovered) cells.
List<CellRect> mergeColumns(
  List<Int32List> cols,
  int side, {
  bool invert = false,
}) {
  final out = <CellRect>[];
  var active = <int, int>{};
  for (var x = 0; x < cols.length; x++) {
    final runs = columnRuns(cols[x], side, invert: invert);
    final next = <int, int>{};
    for (var k = 0; k < runs.length; k += 2) {
      final key = runs[k] * (side + 1) + runs[k + 1];
      next[key] = active.remove(key) ?? x;
    }
    _close(active, x, side, out);
    active = next;
  }
  _close(active, cols.length, side, out);
  return out;
}

void _close(Map<int, int> active, int x1, int side, List<CellRect> out) {
  active.forEach((key, x0) {
    out.add(CellRect(x0, key ~/ (side + 1), x1, key % (side + 1)));
  });
}
