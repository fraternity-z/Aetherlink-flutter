import 'models/perf_models.dart';

/// A fixed-bucket streaming histogram for frame-time distributions.
///
/// This replaces sorting a large sample buffer on every aggregation: each
/// sample is an O(1) bucket increment, memory is bounded by the bucket count
/// (independent of how many frames are observed), and percentiles are read by
/// walking the cumulative counts. This is the same shape (an HdrHistogram-lite)
/// professional latency tooling uses so it can run continuously without GC
/// churn or per-read sorts.
///
/// Values are tracked in `[0, maxTrackedMs]` at [resolutionMs] granularity;
/// anything larger lands in a single overflow bucket but the exact [max] is
/// always retained, so a rare 900ms frozen frame is never lost from the tail.
class Histogram {
  Histogram({double resolutionMs = 0.5, double maxTrackedMs = 250})
      : resolutionMs = resolutionMs,
        maxTrackedMs = maxTrackedMs,
        // +1 for the overflow bucket holding values >= maxTrackedMs.
        _buckets =
            List<int>.filled((maxTrackedMs / resolutionMs).ceil() + 1, 0);

  final double resolutionMs;
  final double maxTrackedMs;
  final List<int> _buckets;

  int _count = 0;
  double _sum = 0;
  double _max = 0;

  int get count => _count;
  double get avg => _count == 0 ? 0 : _sum / _count;
  double get max => _max;

  void add(double valueMs) {
    final v = valueMs < 0 ? 0.0 : valueMs;
    _count++;
    _sum += v;
    if (v > _max) _max = v;
    final idx = (v / resolutionMs).floor();
    _buckets[idx >= _buckets.length ? _buckets.length - 1 : idx]++;
  }

  /// Percentile in `[0, 1]`. Returns the bucket midpoint, or the exact [max]
  /// when the rank falls in the overflow bucket (so the tail is never under-
  /// reported).
  double percentile(double p) {
    if (_count == 0) return 0;
    final target = p * _count;
    var cum = 0;
    for (var i = 0; i < _buckets.length; i++) {
      cum += _buckets[i];
      if (cum >= target) {
        if (i >= _buckets.length - 1) return _max;
        return (i + 0.5) * resolutionMs;
      }
    }
    return _max;
  }

  Stat toStat() => Stat(
        avg: avg,
        p50: percentile(0.50),
        p95: percentile(0.95),
        p99: percentile(0.99),
        max: _max,
      );
}
