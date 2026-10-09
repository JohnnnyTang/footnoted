import 'dart:math' as math;

/// SplitMix64. Owned here rather than `dart:math` Random so that a seed gives
/// the same stream on every SDK version and platform.
class Rng {
  Rng(int seed) : _state = seed;

  int _state;

  int nextInt64() {
    _state += 0x9E3779B97F4A7C15;
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  /// Uniform in [0, 1).
  double nextDouble() => (nextInt64() >>> 11) * (1.0 / (1 << 53));

  /// Uniform in [0, max).
  int nextInt(int max) => (nextDouble() * max).floor();

  double uniform(double lo, double hi) => lo + (hi - lo) * nextDouble();

  bool chance(double p) => nextDouble() < p;

  /// Standard normal (Box–Muller; one draw per call keeps the stream simple).
  double gaussian() {
    final u1 = 1.0 - nextDouble();
    final u2 = nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Picks an index with probability proportional to [weights].
  int weighted(List<double> weights) {
    final total = weights.fold(0.0, (a, b) => a + b);
    var r = nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      r -= weights[i];
      if (r < 0) return i;
    }
    return weights.length - 1;
  }

  /// A child stream, so that adding draws in one place does not shift another.
  Rng fork() => Rng(nextInt64());
}
