import 'models/perf_models.dart';

/// Turns the aggregated numbers into a first-pass attribution, so an AI (or a
/// human) starts from "the bottleneck is the raster thread during chat
/// scrolling" instead of a wall of percentiles.
///
/// The rules are deliberately simple and explainable, and reflect a few
/// professional conventions:
/// - rates are tiered (slow / severe / frozen) instead of a single jank number;
/// - the one-time warm-up spike is called out as startup cost, not steady jank;
/// - a steadily climbing RSS is flagged as a possible leak;
/// - raster suspicions are Impeller-aware (no shader-compilation blame — Impeller
///   precompiles shaders, so the usual culprits are offscreen layers / overdraw
///   / large images, not first-use shader jank).
class Diagnoser {
  const Diagnoser();

  PerfDiagnosis diagnose({
    required PerfSummary summary,
    required List<JankEvent> jankEvents,
    WarmupStats warmup = const WarmupStats(
      frameCount: 0,
      durationMs: 0,
      worstTotalMs: 0,
    ),
  }) {
    if (summary.frameCount == 0) {
      return const PerfDiagnosis(
        primaryBottleneck: Bottleneck.none,
        note: '暂无稳态帧数据（窗口过短或仍处于预热阶段）。',
      );
    }

    final buf = StringBuffer();
    final ctx = _dominantContext(jankEvents);
    final mem = summary.memory;
    final build95 = summary.buildMs.p95;
    final raster95 = summary.rasterMs.p95;
    final leaking =
        mem.rssGrowthMb > 120 && mem.rssMbEnd > mem.rssMbStart * 1.25;

    final smooth = summary.slowFramePct < 0.05 &&
        summary.severeFramePct < 0.015 &&
        summary.frozenFrames == 0;

    if (smooth) {
      buf.write('稳态流畅：慢帧率 ${_pct(summary.slowFramePct)}'
          '（预算 ${summary.budgetMs.toStringAsFixed(1)}ms/帧），无严重或冻结帧。');
      _appendWarmup(buf, warmup);
      if (leaking) {
        buf.write(' 但 RSS 从 ${mem.rssMbStart.toStringAsFixed(0)}MB 升至 '
            '${mem.rssMbEnd.toStringAsFixed(0)}MB（+${mem.rssGrowthMb.toStringAsFixed(0)}MB），'
            '疑似内存泄漏，建议排查未释放的监听器/控制器/图片。');
        return PerfDiagnosis(
            primaryBottleneck: Bottleneck.memory, note: buf.toString());
      }
      _appendCache(buf, mem);
      return PerfDiagnosis(
          primaryBottleneck: Bottleneck.none, note: buf.toString());
    }

    buf.write('慢帧率 ${_pct(summary.slowFramePct)}、严重帧 '
        '${_pct(summary.severeFramePct)}（>2×预算）');
    if (summary.frozenFrames > 0) {
      buf.write('、冻结帧 ${summary.frozenFrames} 次（>700ms，用户可感知卡死）');
    }
    buf.write('。');

    final Bottleneck primary;
    if (raster95 >= build95 * 1.3) {
      primary = Bottleneck.raster;
      buf.write('p95 raster ${raster95.toStringAsFixed(1)}ms 远高于 build '
          '${build95.toStringAsFixed(1)}ms，瓶颈在 GPU/raster 线程$ctx，'
          '常见诱因：离屏图层（Opacity/ClipPath/saveLayer/阴影）、过度绘制或大图。'
          '建议用 debugCheckerboardOffscreenLayers 定位离屏层，'
          '对静态子树加 RepaintBoundary，并降采样大图。');
    } else if (build95 >= raster95 * 1.3) {
      primary = Bottleneck.ui;
      buf.write('p95 build ${build95.toStringAsFixed(1)}ms 远高于 raster '
          '${raster95.toStringAsFixed(1)}ms，瓶颈在 UI 线程$ctx，'
          '疑似 build 过重/过度 rebuild，或主 isolate 上有同步重活；'
          '建议收窄 setState 范围、缓存子树，把重计算挪到 isolate。');
    } else {
      primary = raster95 >= build95 ? Bottleneck.raster : Bottleneck.ui;
      buf.write('build(${build95.toStringAsFixed(1)}ms) 与 raster'
          '(${raster95.toStringAsFixed(1)}ms) 接近，两线程均有压力$ctx。');
    }

    _appendWarmup(buf, warmup);
    if (leaking) {
      buf.write(' 另：RSS 增长 +${mem.rssGrowthMb.toStringAsFixed(0)}MB，疑似内存泄漏。');
    }
    _appendCache(buf, mem);
    return PerfDiagnosis(primaryBottleneck: primary, note: buf.toString());
  }

  /// Notes the one-time warm-up spike as startup cost, so it isn't mistaken for
  /// ongoing jank. Only mentioned when the spike was meaningful (>80ms).
  void _appendWarmup(StringBuffer buf, WarmupStats w) {
    if (w.frameCount > 0 && w.worstTotalMs > 80) {
      buf.write(' 注：预热期最差 ${w.worstTotalMs.toStringAsFixed(0)}ms 尖刺为启动'
          '一次性开销（首帧/首屏构建/图片解码），未计入上述稳态指标。');
    }
  }

  void _appendCache(StringBuffer buf, MemoryStats mem) {
    if (mem.imageCacheMaxMb > 0 &&
        mem.imageCacheMb >= mem.imageCacheMaxMb * 0.9) {
      buf.write(' 图片缓存 ${mem.imageCacheMb.toStringAsFixed(0)}/'
          '${mem.imageCacheMaxMb.toStringAsFixed(0)}MB 接近上限'
          '（${mem.imageCacheCount} 张），可能频繁淘汰重解码。');
    } else if (mem.imageCacheMb > 200) {
      buf.write(' 图片缓存 ${mem.imageCacheMb.toStringAsFixed(0)}MB 偏高。');
    }
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
