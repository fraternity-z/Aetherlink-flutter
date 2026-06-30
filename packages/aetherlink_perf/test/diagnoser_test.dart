import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:aetherlink_perf/src/diagnoser.dart';
import 'package:flutter_test/flutter_test.dart';

PerfSummary _summary({
  required double buildP95,
  required double rasterP95,
  required double slowFramePct,
  double severeFramePct = 0,
  int frozenFrames = 0,
  double imageCacheMb = 0,
  double imageCacheMaxMb = 0,
  int imageCacheCount = 0,
  double rssStart = 200,
  double rssEnd = 210,
}) {
  Stat s(double p95) => Stat(avg: p95 / 2, p50: p95 / 2, p95: p95, p99: p95, max: p95);
  return PerfSummary(
    buildMs: s(buildP95),
    rasterMs: s(rasterP95),
    totalMs: s(buildP95 + rasterP95),
    slowFramePct: slowFramePct,
    severeFramePct: severeFramePct,
    frozenFrames: frozenFrames,
    frameCount: 1000,
    budgetMs: 8.33,
    liveFps: 110,
    memory: MemoryStats(
      rssMbAvg: (rssStart + rssEnd) / 2,
      rssMbPeak: rssEnd,
      rssMbStart: rssStart,
      rssMbEnd: rssEnd,
      imageCacheMb: imageCacheMb,
      imageCacheMaxMb: imageCacheMaxMb,
      imageCacheCount: imageCacheCount,
      liveImages: 100,
    ),
  );
}

void main() {
  const d = Diagnoser();

  test('raster-dominated window is diagnosed as raster-bound', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 5, rasterP95: 40, slowFramePct: 0.15),
      jankEvents: const [],
    );
    expect(diag.primaryBottleneck, Bottleneck.raster);
  });

  test('build-dominated window is diagnosed as UI-bound', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 35, rasterP95: 6, slowFramePct: 0.2),
      jankEvents: const [],
    );
    expect(diag.primaryBottleneck, Bottleneck.ui);
  });

  test('smooth steady-state reports no bottleneck', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 4, rasterP95: 5, slowFramePct: 0.01),
      jankEvents: const [],
    );
    expect(diag.primaryBottleneck, Bottleneck.none);
  });

  test('raster-aware note does not blame shader compilation (Impeller)', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 5, rasterP95: 40, slowFramePct: 0.15),
      jankEvents: const [],
    );
    expect(diag.note.contains('着色器'), isFalse);
    expect(diag.note, contains('离屏图层'));
  });

  test('frozen frames are called out explicitly', () {
    final diag = d.diagnose(
      summary: _summary(
        buildP95: 5,
        rasterP95: 40,
        slowFramePct: 0.15,
        frozenFrames: 3,
      ),
      jankEvents: const [],
    );
    expect(diag.note, contains('冻结帧 3'));
  });

  test('one-time warm-up spike is reported as startup cost, not steady jank', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 4, rasterP95: 5, slowFramePct: 0.01),
      jankEvents: const [],
      warmup: const WarmupStats(frameCount: 10, durationMs: 1200, worstTotalMs: 130),
    );
    expect(diag.primaryBottleneck, Bottleneck.none);
    expect(diag.note, contains('预热'));
    expect(diag.note, contains('130ms'));
  });

  test('climbing RSS on an otherwise smooth window flags a memory leak', () {
    final diag = d.diagnose(
      summary: _summary(
        buildP95: 4,
        rasterP95: 5,
        slowFramePct: 0.01,
        rssStart: 200,
        rssEnd: 400,
      ),
      jankEvents: const [],
    );
    expect(diag.primaryBottleneck, Bottleneck.memory);
    expect(diag.note, contains('泄漏'));
  });

  test('jank events context drives the note suffix', () {
    final events = List.generate(
      4,
      (_) => const JankEvent(
        atMs: 1000,
        totalMs: 48,
        buildMs: 6,
        rasterMs: 42,
        verdict: Bottleneck.raster,
        context: PerfContext(route: '/chat', scrolling: true, streaming: true),
      ),
    );
    final diag = d.diagnose(
      summary: _summary(buildP95: 6, rasterP95: 42, slowFramePct: 0.12),
      jankEvents: events,
    );
    expect(diag.note, contains('/chat'));
    expect(diag.note, contains('滚动'));
  });

  test('snapshot JSON has the v2 schema and shape', () {
    final snap = PerfSnapshot(
      device: const PerfDevice(os: 'android 14', refreshRateHz: 120),
      windowStart: DateTime(2026, 1, 1),
      windowDurationMs: 30000,
      summary: _summary(buildP95: 6, rasterP95: 42, slowFramePct: 0.12),
      warmup: const WarmupStats(frameCount: 8, durationMs: 1400, worstTotalMs: 125),
      jankEvents: const [],
      diagnosis: const PerfDiagnosis(primaryBottleneck: Bottleneck.raster, note: 'x'),
    );
    final json = snap.toJson();
    expect(json['schema'], 'aetherlink_perf/v2');
    expect((json['device'] as Map)['refreshRate'], 120);
    final summary = json['summary'] as Map;
    expect(summary.containsKey('buildMs'), isTrue);
    expect(summary.containsKey('slowFramePct'), isTrue);
    expect(summary.containsKey('frozenFrames'), isTrue);
    expect(summary.containsKey('fps'), isFalse);
    expect((json['warmup'] as Map)['worstTotalMs'], 125);
    expect((json['diagnosis'] as Map)['primaryBottleneck'], 'raster');
  });
}
