import 'models/perf_models.dart';

/// Turns the aggregated numbers into a first-pass attribution, so an AI (or a
/// human) starts from "the bottleneck is the raster thread during chat
/// scrolling" instead of a wall of percentiles.
///
/// The rules are deliberately simple and explainable:
/// 1. If almost no frames missed budget → no bottleneck.
/// 2. Otherwise compare the p95 of build (UI thread) vs raster (GPU thread):
///    whichever dominates is the primary bottleneck.
/// 3. A bloated image cache is flagged as a secondary memory note.
class Diagnoser {
  const Diagnoser();

  PerfDiagnosis diagnose({
    required PerfSummary summary,
    required List<JankEvent> jankEvents,
  }) {
    if (summary.frameCount == 0) {
      return const PerfDiagnosis(
        primaryBottleneck: Bottleneck.none,
        note: '暂无帧数据。',
      );
    }

    final buf = StringBuffer();
    final ctx = _dominantContext(jankEvents);

    if (summary.jankRate < 0.02) {
      buf.write('整体流畅，掉帧率 ${_pct(summary.jankRate)}。');
      if (summary.memory.imageCacheMb > 200) {
        buf.write(' 但图片缓存达 ${summary.memory.imageCacheMb.toStringAsFixed(0)}MB，留意内存。');
        return PerfDiagnosis(primaryBottleneck: Bottleneck.memory, note: buf.toString());
      }
      return PerfDiagnosis(primaryBottleneck: Bottleneck.none, note: buf.toString());
    }

    final build95 = summary.buildMs.p95;
    final raster95 = summary.rasterMs.p95;
    final Bottleneck primary;
    if (raster95 >= build95 * 1.3) {
      primary = Bottleneck.raster;
      buf.write('掉帧率 ${_pct(summary.jankRate)}，p95 raster ${raster95.toStringAsFixed(1)}ms '
          '远高于 build ${build95.toStringAsFixed(1)}ms，瓶颈在 GPU/raster 线程');
      buf.write('$ctx，疑似过度透明/裁剪层、大图或着色器编译导致 GPU 过载。');
    } else if (build95 >= raster95 * 1.3) {
      primary = Bottleneck.ui;
      buf.write('掉帧率 ${_pct(summary.jankRate)}，p95 build ${build95.toStringAsFixed(1)}ms '
          '远高于 raster ${raster95.toStringAsFixed(1)}ms，瓶颈在 UI 线程');
      buf.write('$ctx，疑似 build 过重/过度 rebuild 或主 isolate 上有同步重活。');
    } else {
      primary = raster95 >= build95 ? Bottleneck.raster : Bottleneck.ui;
      buf.write('掉帧率 ${_pct(summary.jankRate)}，build(${build95.toStringAsFixed(1)}ms) '
          '与 raster(${raster95.toStringAsFixed(1)}ms) 接近，两线程均有压力');
      buf.write('$ctx。');
    }

    if (summary.memory.imageCacheMb > 200) {
      buf.write(' 另：图片缓存 ${summary.memory.imageCacheMb.toStringAsFixed(0)}MB 偏高。');
    }
    return PerfDiagnosis(primaryBottleneck: primary, note: buf.toString());
  }

  /// Describes where the jank concentrated (route + scrolling/streaming), as a
  /// short suffix like "（集中在 /chat 滚动+流式 期间）".
  String _dominantContext(List<JankEvent> events) {
    if (events.isEmpty) return '';
    final routeCount = <String, int>{};
    var scrolling = 0;
    var streaming = 0;
    for (final e in events) {
      final r = e.context.route;
      if (r != null) routeCount[r] = (routeCount[r] ?? 0) + 1;
      if (e.context.scrolling) scrolling++;
      if (e.context.streaming) streaming++;
    }
    final parts = <String>[];
    if (routeCount.isNotEmpty) {
      final top = routeCount.entries.reduce((a, b) => a.value >= b.value ? a : b);
      parts.add(top.key);
    }
    final acts = <String>[];
    if (scrolling > events.length / 2) acts.add('滚动');
    if (streaming > events.length / 2) acts.add('流式');
    if (acts.isNotEmpty) parts.add(acts.join('+'));
    if (parts.isEmpty) return '';
    return '（集中在 ${parts.join(' ')} 期间）';
  }

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}
