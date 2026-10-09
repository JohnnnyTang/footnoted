double percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  final i = ((sorted.length - 1) * p).round();
  return sorted[i];
}

/// Summary of frame-to-frame intervals in milliseconds, in the shape exit
/// criterion 2 is stated in: median fps and the share of frames over 32 ms.
Map<String, Object> intervalStats(List<double> intervalsMs) {
  final s = [...intervalsMs]..sort();
  final total = intervalsMs.fold<double>(0, (a, b) => a + b);
  final over32 = intervalsMs.where((v) => v > 32).length;
  final median = percentile(s, 0.5);
  return {
    'frames': intervalsMs.length,
    'span_s': _r(total / 1000),
    'mean_fps': _r(total > 0 ? intervalsMs.length * 1000 / total : 0),
    'median_fps': _r(median > 0 ? 1000 / median : 0),
    'p50_ms': _r(median),
    'p90_ms': _r(percentile(s, 0.9)),
    'p99_ms': _r(percentile(s, 0.99)),
    'max_ms': _r(s.isEmpty ? 0 : s.last),
    'pct_over_32ms': _r(s.isEmpty ? 0 : 100 * over32 / s.length),
  };
}

Map<String, Object> durationStats(List<double> ms) {
  final s = [...ms]..sort();
  return {
    'n': s.length,
    'p50_ms': _r(percentile(s, 0.5)),
    'p90_ms': _r(percentile(s, 0.9)),
    'max_ms': _r(s.isEmpty ? 0 : s.last),
  };
}

double _r(double v) => v.isNaN ? -1 : (v * 100).round() / 100;
