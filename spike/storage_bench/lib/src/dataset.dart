import 'dart:typed_data';

const int level = 20;
const int _yMask = (1 << level) - 1;

int packCell(int x, int y) => (x << level) | y;
int cellX(int id) => id >> level;
int cellY(int id) => id & _yMask;

/// One run of covered cells in a row: `x_start..x_end` inclusive.
class Span {
  const Span(this.y, this.xStart, this.xEnd);
  final int y;
  final int xStart;
  final int xEnd;
}

class Segment {
  Segment(this.id, this.cells, {this.label = ''});

  final int id;

  /// Sorted ascending, unique, z20 IDs (FORMAT.md section 1).
  final Int64List cells;
  final String label;

  /// Run-length spans per row, ordered by (y, x_start). Cached so that span
  /// derivation stays outside the timed regions.
  late final List<Span> _spans = spansOf(cells);
  List<Span> spans() => _spans;
}

/// Cells are ordered by `x` then `y`, so a row's runs are rebuilt by sorting
/// on (y, x) first.
List<Span> spansOf(Int64List cells) {
  final byRow = Int64List.fromList(cells);
  for (var i = 0; i < byRow.length; i++) {
    final id = byRow[i];
    byRow[i] = (cellY(id) << level) | cellX(id);
  }
  byRow.sort();
  final out = <Span>[];
  var i = 0;
  while (i < byRow.length) {
    final y = byRow[i] >> level;
    final x0 = byRow[i] & _yMask;
    var x1 = x0;
    var j = i + 1;
    while (j < byRow.length &&
        byRow[j] >> level == y &&
        (byRow[j] & _yMask) == x1 + 1) {
      x1++;
      j++;
    }
    out.add(Span(y, x0, x1));
    i = j;
  }
  return out;
}

class Dataset {
  Dataset(this.segments, {required this.longLegId, required this.source});

  final List<Segment> segments;

  /// The segment used for the single-leg insert and the delete measurement.
  final int longLegId;
  final String source;

  Segment get longLeg => segments.firstWhere((s) => s.id == longLegId);

  int get rows => segments.fold(0, (n, s) => n + s.cells.length);

  int get spanCount => segments.fold(0, (n, s) => n + s.spans().length);

  Int64List union() {
    final all = Int64List(rows);
    var o = 0;
    for (final s in segments) {
      all.setAll(o, s.cells);
      o += s.cells.length;
    }
    all.sort();
    var w = 0;
    for (var r = 0; r < all.length; r++) {
      if (w == 0 || all[r] != all[w - 1]) all[w++] = all[r];
    }
    return Int64List.sublistView(all, 0, w);
  }
}
