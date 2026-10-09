import 'dart:typed_data';

/// A set of quadkey cells at one level, held as run-length spans per row:
/// row `y` → sorted, disjoint, non-adjacent inclusive intervals `[a, b]` of x.
class SpanSet {
  SpanSet(this.level, this.rows);

  final int level;
  final Map<int, List<int>> rows;

  /// Builds a set from unsorted, possibly overlapping intervals per row.
  factory SpanSet.fromRaw(int level, Map<int, List<int>> raw) {
    final out = <int, List<int>>{};
    for (final e in raw.entries) {
      final merged = mergeIntervals(e.value);
      if (merged.isNotEmpty) out[e.key] = merged;
    }
    return SpanSet(level, out);
  }

  List<int> get sortedRows => rows.keys.toList()..sort();

  int get cellCount {
    var n = 0;
    for (final r in rows.values) {
      for (var i = 0; i < r.length; i += 2) {
        n += r[i + 1] - r[i] + 1;
      }
    }
    return n;
  }

  int get spanCount {
    var n = 0;
    for (final r in rows.values) {
      n += r.length ~/ 2;
    }
    return n;
  }

  bool contains(int x, int y) {
    final r = rows[y];
    if (r == null) return false;
    var lo = 0, hi = r.length ~/ 2 - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (x < r[2 * mid]) {
        hi = mid - 1;
      } else if (x > r[2 * mid + 1]) {
        lo = mid + 1;
      } else {
        return true;
      }
    }
    return false;
  }

  /// Sorted ascending IDs packed as `(x << level) | y` (spike/FORMAT.md §1).
  Int64List toIds() {
    final ids = Int64List(cellCount);
    var k = 0;
    for (final e in rows.entries) {
      final r = e.value;
      for (var i = 0; i < r.length; i += 2) {
        for (var x = r[i]; x <= r[i + 1]; x++) {
          ids[k++] = (x << level) | e.key;
        }
      }
    }
    ids.sort();
    return ids;
  }

  /// "Any child covered" parents at [parentLevel].
  SpanSet rollup(int parentLevel) {
    final k = level - parentLevel;
    if (k == 0) return this;
    final raw = <int, List<int>>{};
    for (final e in rows.entries) {
      final dst = raw.putIfAbsent(e.key >> k, () => <int>[]);
      final r = e.value;
      for (var i = 0; i < r.length; i += 2) {
        dst
          ..add(r[i] >> k)
          ..add(r[i + 1] >> k);
      }
    }
    return SpanSet.fromRaw(parentLevel, raw);
  }

  /// Parents (one level up) whose four children are all in the set.
  SpanSet fullParents() {
    final raw = <int, List<int>>{};
    for (final y in rows.keys) {
      if (y.isOdd) continue;
      final top = rows[y]!;
      final bottom = rows[y + 1];
      if (bottom == null) continue;
      final both = _intersect(top, bottom);
      final out = <int>[];
      for (var i = 0; i < both.length; i += 2) {
        final a = (both[i] + 1) >> 1;
        final b = ((both[i + 1] + 1) >> 1) - 1;
        if (a <= b) out.addAll([a, b]);
      }
      if (out.isNotEmpty) raw[y >> 1] = out;
    }
    return SpanSet(level - 1, raw);
  }

  /// Size of the quadtree-compacted set (the quadkey analogue of H3
  /// `compactCells`), compacting no further up than [minLevel].
  int compactedCount({int minLevel = 0}) {
    var total = 0;
    var current = this;
    while (current.level > minLevel) {
      final parents = current.fullParents();
      final promoted = parents.cellCount;
      total += current.cellCount - 4 * promoted;
      if (promoted == 0) return total;
      current = parents;
    }
    return total + current.cellCount;
  }

  /// Rectangles from a scanline merge: a span continues a rectangle only when
  /// the row directly above has exactly the same span.
  int rectangleCount() {
    var rects = 0;
    var open = <int>{};
    int? prevY;
    for (final y in sortedRows) {
      final r = rows[y]!;
      final next = <int>{};
      final contiguous = prevY != null && y == prevY + 1;
      for (var i = 0; i < r.length; i += 2) {
        final key = r[i] * 0x1000000 + r[i + 1];
        if (!(contiguous && open.contains(key))) rects++;
        next.add(key);
      }
      open = next;
      prevY = y;
    }
    return rects;
  }

  /// Rectangle count per tile at [tileLevel]: spans are split at tile edges,
  /// because the renderer draws "tile minus rectangles" one tile at a time.
  Map<int, int> rectanglesPerTile(int tileLevel) {
    final k = level - tileLevel;
    final tiles = <int, Map<int, List<int>>>{};
    for (final e in rows.entries) {
      final ty = e.key >> k;
      final r = e.value;
      for (var i = 0; i < r.length; i += 2) {
        var a = r[i];
        final b = r[i + 1];
        while (a <= b) {
          final tx = a >> k;
          final end = ((tx + 1) << k) - 1;
          final segEnd = end < b ? end : b;
          final key = (tx << 32) | ty;
          tiles
              .putIfAbsent(key, () => <int, List<int>>{})
              .putIfAbsent(e.key, () => <int>[])
              .addAll([a, segEnd]);
          a = segEnd + 1;
        }
      }
    }
    return {
      for (final t in tiles.entries)
        t.key: SpanSet(level, t.value).rectangleCount(),
    };
  }
}

List<int> mergeIntervals(List<int> flat) {
  final n = flat.length ~/ 2;
  if (n == 0) return const [];
  final order = List<int>.generate(n, (i) => i)
    ..sort((p, q) => flat[2 * p].compareTo(flat[2 * q]));
  final out = <int>[];
  var a = flat[2 * order[0]], b = flat[2 * order[0] + 1];
  for (var j = 1; j < n; j++) {
    final ca = flat[2 * order[j]], cb = flat[2 * order[j] + 1];
    if (ca <= b + 1) {
      if (cb > b) b = cb;
    } else {
      out.addAll([a, b]);
      a = ca;
      b = cb;
    }
  }
  out.addAll([a, b]);
  return out;
}

List<int> _intersect(List<int> p, List<int> q) {
  final out = <int>[];
  var i = 0, j = 0;
  while (i < p.length && j < q.length) {
    final a = p[i] > q[j] ? p[i] : q[j];
    final b = p[i + 1] < q[j + 1] ? p[i + 1] : q[j + 1];
    if (a <= b) out.addAll([a, b]);
    if (p[i + 1] < q[j + 1]) {
      i += 2;
    } else {
      j += 2;
    }
  }
  return out;
}
