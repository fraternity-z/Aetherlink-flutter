import 'dart:ui' show FrameTiming;

import 'models/perf_models.dart';

/// One captured frame: the build (UI thread) / raster (GPU thread) split, the
/// total span, the wall-clock capture time and the app context at that moment.
class _FrameSample {
  _FrameSample({
    required this.wallMs,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
    required this.context,
  });

  /// Milliseconds since [FrameCollector] epoch (host wall clock).
  final int wallMs;
  final double buildMs;
  final double rasterMs;
  final double totalMs;
  final PerfContext context;
}

/// Subscribes to Flutter's frame timings and keeps a bounded ring buffer of
/// per-frame samples, splitting each frame into its UI-thread (`buildDuration`)
/// and raster-thread (`rasterDuration`) costs — the split that lets us tell a
/// UI-bound jank from a GPU-bound one.
class FrameCollector {
  FrameCollector({this.capacity = 8000});

  /// Max retained frames (~60s at 120fps). Oldest are dropped.
  final int capacity;

  final List<_FrameSample> _samples = <_FrameSample>[];
  DateTime _epoch = DateTime.now();

  /// Resets the buffer and the window epoch.
  void reset() {
    _samples.clear();
    _epoch = DateTime.now();
  }

  DateTime get epoch => _epoch;

  int get length => _samples.length;

  /// Most recent frame's build/raster/total in ms, or null if none yet.
  ({double build, double raster, double total})? get latest {
    if (_samples.isEmpty) return null;
    final s = _samples.last;
    return (build: s.buildMs, raster: s.rasterMs, total: s.totalMs);
  }

  /// Ingests a batch of [FrameTiming]s (the signature of
  /// `WidgetsBinding.addTimingsCallback`). [context] is the app context to tag
  /// these frames with (read once per batch — batches span a few frames).
  void addTimings(List<FrameTiming> timings, PerfContext context) {
    final now = DateTime.now().difference(_epoch).inMilliseconds;
    for (final t in timings) {
      _samples.add(_FrameSample(
        wallMs: now,
        buildMs: _ms(t.buildDuration),
        rasterMs: _ms(t.rasterDuration),
        totalMs: _ms(t.totalSpan),
        context: context,
      ));
    }
    if (_samples.length > capacity) {
      _samples.removeRange(0, _samples.length - capacity);
    }
  }

  /// FPS estimated over roughly the last [seconds] of wall time from the frame
  /// count, falling back to instantaneous `1000/totalSpan` when too few frames.
  double recentFps([int seconds = 1]) {
    if (_samples.isEmpty) return 0;
    final cutoff = _samples.last.wallMs - seconds * 1000;
    var count = 0;
    var minMs = _samples.last.wallMs;
    for (var i = _samples.length - 1; i >= 0; i--) {
      if (_samples[i].wallMs < cutoff) break;
      count++;
      minMs = _samples[i].wallMs;
    }
    final span = _samples.last.wallMs - minMs;
    if (count < 2 || span <= 0) {
      final last = _samples.last.totalMs;
      return last <= 0 ? 0 : (1000 / last).clamp(0, 240).toDouble();
    }
    return (count - 1) * 1000 / span;
  }

  /// Builds the aggregated summary stats over the whole retained window.
  /// [budgetMs] is the per-frame budget (`1000 / refreshRate`).
  ({
    Stat fps,
    Stat build,
    Stat raster,
    Stat total,
    double jankRate,
    int frameCount,
  }) aggregate(double budgetMs) {
    if (_samples.isEmpty) {
      return (
        fps: Stat.empty(),
        build: Stat.empty(),
        raster: Stat.empty(),
        total: Stat.empty(),
        jankRate: 0,
        frameCount: 0,
      );
    }
    final builds = <double>[];
    final rasters = <double>[];
    final totals = <double>[];
    final fpsList = <double>[];
    var jank = 0;
    for (final s in _samples) {
      builds.add(s.buildMs);
      rasters.add(s.rasterMs);
      totals.add(s.totalMs);
      fpsList.add(s.totalMs <= 0 ? 0 : (1000 / s.totalMs).clamp(0, 240).toDouble());
      if (s.totalMs > budgetMs) jank++;
    }
    return (
      fps: _statOf(fpsList, lowerIsWorse: true),
      build: _statOf(builds),
      raster: _statOf(rasters),
      total: _statOf(totals),
      jankRate: jank / _samples.length,
      frameCount: _samples.length,
    );
  }

  /// The worst [limit] jank frames (total span over [budgetMs]), newest-biased,
  /// each classified UI- vs raster-bound and tagged with its context.
  List<JankEvent> jankEvents(double budgetMs, {int limit = 30}) {
    final janks = _samples.where((s) => s.totalMs > budgetMs).toList()
      ..sort((a, b) => b.totalMs.compareTo(a.totalMs));
    final top = janks.take(limit).toList()
      ..sort((a, b) => a.wallMs.compareTo(b.wallMs));
    return top
        .map((s) => JankEvent(
              atMs: s.wallMs,
              totalMs: s.totalMs,
              buildMs: s.buildMs,
              rasterMs: s.rasterMs,
              verdict: s.rasterMs >= s.buildMs ? Bottleneck.raster : Bottleneck.ui,
              context: s.context,
            ))
        .toList();
  }

  static double _ms(Duration d) => d.inMicroseconds / 1000.0;

  static Stat _statOf(List<double> values, {bool lowerIsWorse = false}) {
    if (values.isEmpty) return Stat.empty();
    final sorted = [...values]..sort();
    final n = sorted.length;
    double pct(double p) {
      // For FPS, "p95" should report the bad tail (low FPS), so invert.
      final q = lowerIsWorse ? 1 - p : p;
      final idx = ((n - 1) * q).round().clamp(0, n - 1);
      return sorted[idx];
    }

    final sum = values.fold<double>(0, (a, b) => a + b);
    return Stat(
      avg: sum / n,
      p50: pct(0.50),
      p95: pct(0.95),
      p99: pct(0.99),
      max: lowerIsWorse ? sorted.first : sorted.last,
    );
  }
}
