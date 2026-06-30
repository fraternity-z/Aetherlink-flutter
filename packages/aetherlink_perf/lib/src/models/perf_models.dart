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

/// Memory figures over the window (all in MB except the counts).
///
/// [rssMbStart]/[rssMbEnd] expose the trend: a steadily climbing RSS that never
/// comes back down is the runtime signal of a leak — far more useful than a
/// single average. The image-cache count + configured max let the AI reason
/// about cache pressure ("90% full, 300 live images") rather than just a size.
class MemoryStats {
  const MemoryStats({
    required this.rssMbAvg,
    required this.rssMbPeak,
    required this.rssMbStart,
    required this.rssMbEnd,
    required this.imageCacheMb,
    required this.imageCacheMaxMb,
    required this.imageCacheCount,
    required this.liveImages,
  });

  final double rssMbAvg;
  final double rssMbPeak;
  final double rssMbStart;
  final double rssMbEnd;
  final double imageCacheMb;
  final double imageCacheMaxMb;
  final int imageCacheCount;
  final int liveImages;

  /// RSS growth across the window in MB (end − start); positive means climbing.
  double get rssGrowthMb => rssMbEnd - rssMbStart;

  Map<String, dynamic> toJson() => {
        'rssMbAvg': _round(rssMbAvg),
        'rssMbPeak': _round(rssMbPeak),
        'rssMbStart': _round(rssMbStart),
        'rssMbEnd': _round(rssMbEnd),
        'rssGrowthMb': _round(rssGrowthMb),
        'imageCacheMb': _round(imageCacheMb),
        'imageCacheMaxMb': _round(imageCacheMaxMb),
        'imageCacheCount': imageCacheCount,
        'liveImages': liveImages,
      };

  static MemoryStats empty() => const MemoryStats(
        rssMbAvg: 0,
        rssMbPeak: 0,
        rssMbStart: 0,
        rssMbEnd: 0,
        imageCacheMb: 0,
        imageCacheMaxMb: 0,
        imageCacheCount: 0,
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

/// Steady-state frame distribution + tiered jank + memory for the window.
///
/// Deliberately reports NO headline "FPS": on a variable-refresh panel an idle
/// screen produces few frames, so an average FPS is meaningless. Professional
/// rendering metrics are frame-time percentiles plus tiered slow/frozen frame
/// rates (cf. Firebase Performance's >16ms "slow" / >700ms "frozen", and
/// Apple's hitch ratio). [liveFps] is kept only as a count-based instantaneous
/// gauge for the live overlay, not a window summary.
///
/// All rates here are STEADY-STATE: warm-up frames (first-paint, route build,
/// shader/image warm-up) are excluded and reported separately in [WarmupStats]
/// so a one-time launch spike doesn't masquerade as ongoing jank.
class PerfSummary {
  const PerfSummary({
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
    required this.slowFramePct,
    required this.severeFramePct,
    required this.frozenFrames,
    required this.frameCount,
    required this.budgetMs,
    required this.liveFps,
    required this.memory,
  });

  final Stat buildMs;
  final Stat rasterMs;
  final Stat totalMs;

  /// Fraction (0..1) of steady-state frames over the per-frame budget.
  final double slowFramePct;

  /// Fraction (0..1) of steady-state frames over 2× the budget (clearly felt).
  final double severeFramePct;

  /// Count of frames over 700ms — perceived as a freeze/ANR-like stall.
  final int frozenFrames;

  /// Steady-state frame count (warm-up excluded).
  final int frameCount;

  /// Per-frame budget used for the tiers, `1000 / refreshRate`.
  final double budgetMs;

  /// Instantaneous count-based FPS at snapshot time (live gauge, not a summary).
  final double liveFps;

  final MemoryStats memory;

  Map<String, dynamic> toJson() => {
        'frameCount': frameCount,
        'budgetMs': _round(budgetMs),
        'liveFps': _round(liveFps),
        'buildMs': buildMs.toJson(),
        'rasterMs': rasterMs.toJson(),
        'totalMs': totalMs.toJson(),
        'slowFramePct': _round(slowFramePct, 3),
        'severeFramePct': _round(severeFramePct, 3),
        'frozenFrames': frozenFrames,
        'memory': memory.toJson(),
      };
}

/// One-time warm-up phase stats (first-paint / route build / image+shader
/// warm-up), kept apart from steady-state so a launch spike is visible but not
/// blamed on ongoing performance.
class WarmupStats {
  const WarmupStats({
    required this.frameCount,
    required this.durationMs,
    required this.worstTotalMs,
  });

  final int frameCount;
  final int durationMs;
  final double worstTotalMs;

  Map<String, dynamic> toJson() => {
        'frameCount': frameCount,
        'durationMs': durationMs,
        'worstTotalMs': _round(worstTotalMs),
      };

  static WarmupStats empty() =>
      const WarmupStats(frameCount: 0, durationMs: 0, worstTotalMs: 0);
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
    required this.warmup,
    required this.jankEvents,
    required this.diagnosis,
  });

  static const String schema = 'aetherlink_perf/v2';

  final PerfDevice device;
  final DateTime windowStart;
  final int windowDurationMs;
  final PerfSummary summary;
  final WarmupStats warmup;
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
        'warmup': warmup.toJson(),
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
