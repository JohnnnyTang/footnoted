import 'dart:math' as math;
import 'dart:typed_data';

import 'rasterize.dart';
import 'tile_math.dart';

/// The dilation radius in cells for row [y]: `ceil(bufferMeters / width)`,
/// where width is the row's ground width at its own latitude (F01.6).
int dilationRadiusCells(double bufferMeters, int y, [int level = cellLevel]) {
  if (bufferMeters <= 0) return 0;
  return (bufferMeters / rowWidthMeters(y, level)).ceil();
}

final Map<int, Int32List> _halfWidthCache = {};

/// `hw[|dy|] = floor(sqrt(r² - dy²))`: the half-width of the disk mask of
/// radius [r] at row offset `dy`.
Int32List diskHalfWidths(int r) => _halfWidthCache.putIfAbsent(r, () {
  final hw = Int32List(r + 1);
  final r2 = r * r;
  for (var dy = 0; dy <= r; dy++) {
    var w = math.sqrt(r2 - dy * dy).floor();
    while ((w + 1) * (w + 1) + dy * dy <= r2) {
      w++;
    }
    while (w * w + dy * dy > r2) {
      w--;
    }
    hw[dy] = w;
  }
  return hw;
});

/// Dilates [cells] (IDs at [level]) by [bufferMeters]: every cell whose
/// offset `(dx, dy)` from a source cell satisfies `dx² + dy² ≤ r²`, with
/// `r` = [dilationRadiusCells] of the source row. Rows beyond the Mercator
/// world are dropped; columns wrap at the antimeridian. Returns sorted
/// unique IDs.
Int64List dilateCells(
  List<int> cells,
  double bufferMeters, {
  int level = cellLevel,
}) {
  if (cells.isEmpty || bufferMeters <= 0) return sortedUnique(cells);
  final n = tilesPerAxis(level);
  final mask = n - 1;

  // Source cells as row runs: sort by (y, x).
  final yx = Int64List(cells.length);
  for (var i = 0; i < cells.length; i++) {
    final id = cells[i];
    yx[i] = ((id & mask) << level) | (id >> level);
  }
  yx.sort();

  // Target intervals per row, packed as (start << level) | end.
  final rows = <int, List<int>>{};
  void addInterval(int ty, int start, int end) {
    if (end - start + 1 >= n) {
      (rows[ty] ??= <int>[]).add(mask); // (0 << level) | (n - 1)
      return;
    }
    final list = rows[ty] ??= <int>[];
    if (start < 0) {
      list.add(((start + n) << level) | mask);
      start = 0;
    }
    if (end >= n) {
      list.add(end - n);
      end = n - 1;
    }
    list.add((start << level) | end);
  }

  var i = 0;
  var lastY = -1;
  var r = 0;
  late Int32List hw;
  while (i < yx.length) {
    final y = yx[i] >> level;
    final xa = yx[i] & mask;
    var xb = xa;
    var j = i + 1;
    while (j < yx.length && yx[j] >> level == y && (yx[j] & mask) <= xb + 1) {
      xb = yx[j] & mask;
      j++;
    }
    i = j;
    if (y != lastY) {
      r = dilationRadiusCells(bufferMeters, y, level);
      hw = diskHalfWidths(r);
      lastY = y;
    }
    final y0 = math.max(0, y - r);
    final y1 = math.min(n - 1, y + r);
    for (var ty = y0; ty <= y1; ty++) {
      final w = hw[(ty - y).abs()];
      addInterval(ty, xa - w, xb + w);
    }
  }

  // Merge intervals per row and count the output.
  final merged = <int, Int64List>{};
  var total = 0;
  rows.forEach((ty, list) {
    list.sort();
    final out = <int>[];
    var cs = list.first >> level;
    var ce = list.first & mask;
    for (var k = 1; k < list.length; k++) {
      final s = list[k] >> level;
      final e = list[k] & mask;
      if (s <= ce + 1) {
        if (e > ce) ce = e;
      } else {
        out
          ..add(cs)
          ..add(ce);
        total += ce - cs + 1;
        cs = s;
        ce = e;
      }
    }
    out
      ..add(cs)
      ..add(ce);
    total += ce - cs + 1;
    merged[ty] = Int64List.fromList(out);
  });

  final result = Int64List(total);
  var w = 0;
  merged.forEach((ty, spans) {
    for (var k = 0; k < spans.length; k += 2) {
      for (var x = spans[k]; x <= spans[k + 1]; x++) {
        result[w++] = (x << level) | ty;
      }
    }
  });
  return result..sort();
}
