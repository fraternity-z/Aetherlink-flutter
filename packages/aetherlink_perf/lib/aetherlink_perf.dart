/// Aetherlink in-app performance monitor.
///
/// A dependency-free, self-contained package that:
/// - subscribes to Flutter frame timings and splits each frame into its
///   UI-thread (`buildDuration`) and raster (`rasterDuration`) costs;
/// - aggregates percentiles, detects jank events and tags them with app
///   context (route / streaming / scrolling / message count);
/// - runs a rule-based diagnosis of the primary bottleneck;
/// - exports an AI-friendly JSON report; and
/// - paints a draggable floating overlay styled after the original web app.
///
/// Typical wiring:
/// ```dart
/// // In MaterialApp.builder:
/// builder: (context, child) => PerfOverlayHost(
///   enabled: showPerfMonitor,
///   child: child ?? const SizedBox.shrink(),
/// ),
///
/// // Toggle collection with the same flag:
/// showPerfMonitor ? PerfMonitor.instance.start() : PerfMonitor.instance.stop();
///
/// // Optionally report context from the app:
/// PerfMonitor.instance.setRoute('/chat');
/// PerfMonitor.instance.setStreaming(true);
/// ```
library;

export 'src/models/perf_models.dart';
export 'src/perf_monitor.dart' show PerfMonitor, PerfLiveMetrics;
export 'src/ui/perf_overlay.dart' show PerfOverlay, PerfOverlayHost;
