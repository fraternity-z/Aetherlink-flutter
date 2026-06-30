/// Immutable value types for the performance monitor and its AI-friendly JSON
/// export. Kept as plain Dart (no freezed/json_serializable) so the package
/// stays dependency-free.
library;

/// Which render thread (or resource) a slow frame / the overall window is bound
/// by. This is the core diagnostic axis: a janky frame is almost always either
/// UI-thread (build/layout) bound or raster (GPU) bound, and the fix differs.
enum Bottleneck {
  /// UI thread (`buildDuration`) dominates — expensive build/layout, excessive
  /// rebuilds, or synchronous work on the root isolate.
  ui('ui'),

  /// Raster/GPU thread (`rasterDuration`) dominates — heavy clips/opacity/blur,
  /// shader compilation, overdraw or large images.
  raster('raster'),

  /// Memory pressure (RSS climbing, image cache bloat) rather than a frame-time
  /// problem.
  memory('memory'),

  /// No clear bottleneck in the window.
  none('none');

  const Bottleneck(this.id);

  final String id;
}

/// A distribution summary for one metric over the aggregation window.
///
/// Percentiles matter far more than the mean for jank analysis: the mean hides
/// the tail, and it is the p95/p99 frames that the user actually feels.
class Stat {
  const Stat({
    required this.avg,
    required this.p50,
    required this.p95,
    required this.p99,
    required this.max,
  });

  final double avg;
  final double p50;
  final double p95;
  final double p99;
  final double max;

  Map<String, dynamic> toJson() => {
        'avg': _round(avg),
        'p50': _round(p50),
        'p95': _round(p95),
        'p99': _round(p99),
        'max': _round(max),
      };

  static Stat empty() =>
      const Stat(avg: 0, p50: 0, p95: 0, p99: 0, max: 0);
}

/// Memory figures over the window (all in MB except [liveImages]).
class MemoryStats {
  const MemoryStats({
    required this.rssMbAvg,
    required this.rssMbPeak,
    required this.imageCacheMb,
    required this.liveImages,
  });

  final double rssMbAvg;
  final double rssMbPeak;
  final double imageCacheMb;
  final int liveImages;

  Map<String, dynamic> toJson() => {
        'rssMbAvg': _round(rssMbAvg),
        'rssMbPeak': _round(rssMbPeak),
        'imageCacheMb': _round(imageCacheMb),
        'liveImages': liveImages,
      };

  static MemoryStats empty() => const MemoryStats(
        rssMbAvg: 0,
        rssMbPeak: 0,
        imageCacheMb: 0,
        liveImages: 0,
      );
}

/// A snapshot of "what the app was doing" at a moment, attached to jank events
/// so the AI can attribute a slow frame to a concrete scenario (e.g. scrolling
/// the chat while streaming) rather than guessing.
class PerfContext {
  const PerfContext({
    this.route,
    this.streaming = false,
    this.scrolling = false,
    this.messages,
  });

  /// Current router location (e.g. `/chat`), if reported by the host app.
  final String? route;

  /// Whether a model response is being streamed.
  final bool streaming;

  /// Whether a scrollable is actively being dragged/flung.
  final bool scrolling;

  /// Number of messages in the visible conversation, if reported.
  final int? messages;

  static const PerfContext empty = PerfContext();

  PerfContext copyWith({
    String? route,
    bool? streaming,
    bool? scrolling,
    int? messages,
  }) =>
      PerfContext(
        route: route ?? this.route,
        streaming: streaming ?? this.streaming,
        scrolling: scrolling ?? this.scrolling,
        messages: messages ?? this.messages,
      );

  Map<String, dynamic> toJson() => {
        if (route != null) 'route': route,
        'streaming': streaming,
        'scrolling': scrolling,
        if (messages != null) 'messages': messages,
      };
}

/// A single frame that missed its budget, with the build/raster split and the
/// context captured when it happened.
class JankEvent {
  const JankEvent({
    required this.atMs,
    required this.totalMs,
    required this.buildMs,
    required this.rasterMs,
    required this.verdict,
    required this.context,
  });

  /// Milliseconds from the start of the window.
  final int atMs;
  final double totalMs;
  final double buildMs;
  final double rasterMs;
  final Bottleneck verdict;
  final PerfContext context;

  Map<String, dynamic> toJson() => {
        't': '+${(atMs / 1000).toStringAsFixed(1)}s',
        'totalMs': _round(totalMs),
        'buildMs': _round(buildMs),
        'rasterMs': _round(rasterMs),
        'verdict': verdict.id,
        'context': context.toJson(),
      };
}

/// Aggregated distribution + memory for the window.
class PerfSummary {
  const PerfSummary({
    required this.fps,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
    required this.jankRate,
    required this.frameCount,
    required this.memory,
  });

  final Stat fps;
  final Stat buildMs;
  final Stat rasterMs;
  final Stat totalMs;

  /// Fraction (0..1) of frames that exceeded the per-frame budget.
  final double jankRate;
  final int frameCount;
  final MemoryStats memory;

  Map<String, dynamic> toJson() => {
        'fps': fps.toJson(),
        'buildMs': buildMs.toJson(),
        'rasterMs': rasterMs.toJson(),
        'totalMs': totalMs.toJson(),
        'jankRate': _round(jankRate, 3),
        'frameCount': frameCount,
        'memory': memory.toJson(),
      };
}

/// The rule-based first pass at attribution, so the AI starts from "already
/// localized to a thread" rather than raw numbers.
class PerfDiagnosis {
  const PerfDiagnosis({required this.primaryBottleneck, required this.note});

  final Bottleneck primaryBottleneck;
  final String note;

  Map<String, dynamic> toJson() => {
        'primaryBottleneck': primaryBottleneck.id,
        'note': note,
      };
}

/// Device / display context. [refreshRateHz] is critical: the per-frame budget
/// is `1000 / refreshRateHz` ms, not a hard-coded 16.6ms — otherwise every
/// frame on a 90/120Hz panel looks janky.
class PerfDevice {
  const PerfDevice({
    required this.os,
    required this.refreshRateHz,
    this.model,
  });

  final String os;
  final double refreshRateHz;
  final String? model;

  Map<String, dynamic> toJson() => {
        if (model != null) 'model': model,
        'os': os,
        'refreshRate': _round(refreshRateHz, 0),
      };
}

/// The full export: device + window + aggregated summary + discrete jank events
/// + a pre-computed diagnosis. Designed to be a few KB and copy-pasteable into
/// an AI prompt.
class PerfSnapshot {
  const PerfSnapshot({
    required this.device,
    required this.windowStart,
    required this.windowDurationMs,
    required this.summary,
    required this.jankEvents,
    required this.diagnosis,
  });

  static const String schema = 'aetherlink_perf/v1';

  final PerfDevice device;
  final DateTime windowStart;
  final int windowDurationMs;
  final PerfSummary summary;
  final List<JankEvent> jankEvents;
  final PerfDiagnosis diagnosis;

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'device': device.toJson(),
        'window': {
          'start': windowStart.toIso8601String(),
          'durationMs': windowDurationMs,
        },
        'summary': summary.toJson(),
        'jankEvents': jankEvents.map((e) => e.toJson()).toList(),
        'diagnosis': diagnosis.toJson(),
      };
}

double _round(num v, [int digits = 1]) {
  final f = _pow10(digits);
  return (v * f).round() / f;
}

double _pow10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}
