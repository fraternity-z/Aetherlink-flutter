import 'package:aetherlink_perf/src/histogram.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty histogram reports zeros', () {
    final h = Histogram();
    expect(h.count, 0);
    expect(h.avg, 0);
    expect(h.percentile(0.5), 0);
  });

  test('percentiles approximate a uniform distribution within bucket width', () {
    final h = Histogram(resolutionMs: 0.5, maxTrackedMs: 250);
    for (var i = 1; i <= 100; i++) {
      h.add(i.toDouble()); // 1..100 ms
    }
    expect(h.count, 100);
    expect(h.avg, closeTo(50.5, 0.001));
    expect(h.percentile(0.50), closeTo(50, 1.0));
    expect(h.percentile(0.95), closeTo(95, 1.0));
    expect(h.percentile(0.99), closeTo(99, 1.0));
  });

  test('overflow tail keeps the exact max, not the bucket cap', () {
    final h = Histogram(resolutionMs: 0.5, maxTrackedMs: 250);
    for (var i = 0; i < 90; i++) {
      h.add(5);
    }
    for (var i = 0; i < 10; i++) {
      h.add(900); // frozen frames beyond the tracked range
    }
    expect(h.max, 900);
    // p95/p99 land in the overflow bucket and must report the real max,
    // while p50 stays in the dense low bucket.
    expect(h.percentile(0.50), closeTo(5.25, 0.001));
    expect(h.percentile(0.95), 900);
    expect(h.percentile(0.99), 900);
  });

  test('negative inputs are clamped to zero', () {
    final h = Histogram();
    h.add(-3);
    expect(h.max, 0);
    expect(h.count, 1);
  });
}
