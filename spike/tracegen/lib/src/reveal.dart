import 'dart:typed_data';

import 'package:footnoted_geo/footnoted_geo.dart';

import 'model.dart';

/// The cells a segment reveals at [level] (spike/FORMAT.md §2 `reveal`).
Int64List revealSegment(Segment s, int level) {
  final points = [for (final p in s.points) p.latLng];
  final List<int> source = switch (s.reveal) {
    Reveal.line => rasterizePolyline(points, mode: s.mode, level: level),
    Reveal.endpoints => [
      ...rasterizePolyline([points.first], level: level),
      ...rasterizePolyline([points.last], level: level),
    ],
  };
  return dilateCells(source, s.bufferM, level: level);
}

/// Run-length spans `(y, x_start, x_end)` needed to store [ids] (one row
/// per maximal horizontal run; a run across the antimeridian counts twice).
int countSpans(List<int> ids, int level) {
  if (ids.isEmpty) return 0;
  final mask = (1 << level) - 1;
  final yx = Int64List(ids.length);
  for (var i = 0; i < ids.length; i++) {
    yx[i] = ((ids[i] & mask) << level) | (ids[i] >> level);
  }
  yx.sort();
  var spans = 1;
  for (var i = 1; i < yx.length; i++) {
    if (yx[i] != yx[i - 1] + 1 || (yx[i] >> level) != (yx[i - 1] >> level)) {
      spans++;
    }
  }
  return spans;
}

/// Accumulates sorted unique cell sets into their union, merging in batches
/// so that memory stays near the union size.
class UnionBuilder {
  UnionBuilder({this.batch = 1 << 22});

  final int batch;
  Int64List _union = Int64List(0);
  final List<Int64List> _pending = [];
  int _pendingCount = 0;

  void add(Int64List cells) {
    _pending.add(cells);
    _pendingCount += cells.length;
    if (_pendingCount >= batch) _merge();
  }

  void _merge() {
    if (_pending.isEmpty) return;
    final all = Int64List(_union.length + _pendingCount)
      ..setRange(0, _union.length, _union);
    var w = _union.length;
    for (final p in _pending) {
      all.setRange(w, w + p.length, p);
      w += p.length;
    }
    _pending.clear();
    _pendingCount = 0;
    _union = Int64List.fromList(sortedUnique(all));
  }

  Int64List build() {
    _merge();
    return _union;
  }
}
