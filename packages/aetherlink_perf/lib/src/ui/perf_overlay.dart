import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../models/perf_models.dart';
import '../perf_monitor.dart';

/// Wraps [child] with the draggable performance overlay when [enabled].
///
/// Drop this in `MaterialApp.builder` so the panel floats above every route.
/// When disabled it returns [child] untouched (zero overhead).
class PerfOverlayHost extends StatelessWidget {
  const PerfOverlayHost({super.key, required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [child, const PerfOverlay()],
    );
  }
}

/// The floating, draggable performance panel. Visual language mirrors the
/// original web `EnhancedPerformanceMonitor` (dark translucent card, blur, a
/// green→blue gradient title bar, collapse/expand, colored value chips), but the
/// numbers are real per-thread frame metrics and it can copy an AI-ready report.
class PerfOverlay extends StatefulWidget {
  const PerfOverlay({super.key});

  @override
  State<PerfOverlay> createState() => _PerfOverlayState();
}

class _PerfOverlayState extends State<PerfOverlay> {
  // Remembered for the session so the panel keeps its spot across rebuilds.
  static Offset _position = const Offset(12, 80);
  static bool _expanded = false;

  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxX = media.size.width - 56;
    final maxY = media.size.height - 56;
    final left = _position.dx.clamp(0.0, maxX > 0 ? maxX : 0.0);
    final top = _position.dy.clamp(media.padding.top, maxY > 0 ? maxY : 0.0);

    return Positioned(
      left: left,
      top: top,
      child: ValueListenableBuilder<PerfLiveMetrics>(
        valueListenable: PerfMonitor.instance.live,
        builder: (context, m, _) {
          // NOTE: deliberately NOT using BackdropFilter here. On Android's
          // Impeller backend (release builds) a BackdropFilter could leave the
          // whole panel unpainted; a plain opaque card renders reliably.
          return Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_expanded ? 12 : 10),
              child: Container(
                width: _expanded ? 264 : null,
                decoration: BoxDecoration(
                  color: const Color(0xF2121212), // near-opaque dark card
                  borderRadius: BorderRadius.circular(_expanded ? 12 : 10),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Only stretch when expanded: expanded has a bounded `width`
                  // (264) so stretch resolves fine. Collapsed has `width: null`,
                  // and the Positioned (left/top only) hands down an UNBOUNDED
                  // width — stretching to infinity throws/renders nothing, which
                  // is why the collapsed panel used to vanish. `start` lets the
                  // bar size to its content instead.
                  crossAxisAlignment:
                      _expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
                  children: [
                    _titleBar(m),
                    if (_expanded) _body(m),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _titleBar(PerfLiveMetrics m) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => setState(() => _position += d.delta),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _expanded ? 12 : 9,
          vertical: _expanded ? 10 : 6,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x334CAF50), Color(0x332196F3)], // green→blue 0.2
          ),
          borderRadius: _expanded
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_indicator, size: _expanded ? 16 : 14, color: Colors.white70),
            const SizedBox(width: 2),
            Icon(Icons.speed, size: _expanded ? 18 : 14, color: Colors.white),
            if (!_expanded) ...[
              const SizedBox(width: 6),
              Text(
                m.fps.toStringAsFixed(0),
                style: TextStyle(
                  color: _fpsColor(m.fps),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
            if (_expanded) ...[
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '性能监控',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.expand_less, size: 18, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(PerfLiveMetrics m) {
    final budget = PerfMonitor.instance.budgetMs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('FPS', m.fps.toStringAsFixed(0), _fpsColor(m.fps)),
          _row('Build (UI)', '${m.buildMs.toStringAsFixed(1)}ms', _frameColor(m.buildMs, budget)),
          _row('Raster (GPU)', '${m.rasterMs.toStringAsFixed(1)}ms', _frameColor(m.rasterMs, budget)),
          _row('掉帧率', '${(m.jankRate * 100).toStringAsFixed(1)}%', _jankColor(m.jankRate)),
          _row('内存 RSS', '${m.rssMb.toStringAsFixed(0)}MB', _memColor(m.rssMb)),
          _row('图片缓存', '${m.imageCacheMb.toStringAsFixed(0)}MB', _memColor(m.imageCacheMb * 2)),
          const SizedBox(height: 6),
          _verdictChip(m.verdict, m.jankRate),
          const SizedBox(height: 8),
          _copyButton(),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color chipColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: chipColor.withValues(alpha: 0.6)),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verdictChip(Bottleneck v, double jankRate) {
    final (label, color) = switch (v) {
      Bottleneck.ui => ('瓶颈：UI 线程', const Color(0xFFFFB74D)),
      Bottleneck.raster => ('瓶颈：Raster/GPU', const Color(0xFFFF8A65)),
      Bottleneck.memory => ('瓶颈：内存', const Color(0xFFBA68C8)),
      Bottleneck.none => ('无明显瓶颈', const Color(0xFF66BB6A)),
    };
    final show = jankRate >= 0.02 ? label : '无明显瓶颈';
    final c = jankRate >= 0.02 ? color : const Color(0xFF66BB6A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(show,
          style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _copyButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0x332196F3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
        label: Text(_copied ? '已复制' : '复制报告给 AI', style: const TextStyle(fontSize: 12.5)),
        onPressed: _onCopy,
      ),
    );
  }

  Future<void> _onCopy() async {
    final json = PerfMonitor.instance.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Color _fpsColor(double fps) {
    final rate = PerfMonitor.instance.budgetMs > 0 ? 1000 / PerfMonitor.instance.budgetMs : 60;
    if (fps >= rate * 0.9) return const Color(0xFF66BB6A);
    if (fps >= rate * 0.5) return const Color(0xFFFFB74D);
    return const Color(0xFFE57373);
  }

  Color _frameColor(double ms, double budget) {
    if (ms <= budget) return const Color(0xFF66BB6A);
    if (ms <= budget * 2) return const Color(0xFFFFB74D);
    return const Color(0xFFE57373);
  }

  Color _jankColor(double rate) {
    if (rate < 0.02) return const Color(0xFF66BB6A);
    if (rate < 0.1) return const Color(0xFFFFB74D);
    return const Color(0xFFE57373);
  }

  Color _memColor(double mb) {
    if (mb < 100) return const Color(0xFF66BB6A);
    if (mb < 200) return const Color(0xFFFFB74D);
    return const Color(0xFFE57373);
  }
}
