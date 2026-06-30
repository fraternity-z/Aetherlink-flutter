import 'dart:io' show ProcessInfo;

import 'package:flutter/painting.dart' show PaintingBinding;

import 'models/perf_models.dart';

/// Samples process memory (RSS) and Flutter's image cache. Both are pure-Dart,
/// zero-dependency sources: RSS via `dart:io ProcessInfo.currentRss`, the image
/// cache via `PaintingBinding.instance.imageCache`.
///
/// RSS is the most portable "is memory climbing?" signal; the image cache size
/// is the usual culprit for a chat app that renders many images.
class MemoryCollector {
  final List<double> _rssMb = <double>[];

  static const int _capacity = 600; // ~5 min at one sample/0.5s

  double _firstRssMb = 0;
  double _lastRssMb = 0;
  double _lastImageCacheMb = 0;
  double _imageCacheMaxMb = 0;
  int _lastImageCacheCount = 0;
  int _lastLiveImages = 0;

  double get lastRssMb => _lastRssMb;
  double get lastImageCacheMb => _lastImageCacheMb;
  int get lastLiveImages => _lastLiveImages;

  void reset() {
    _rssMb.clear();
    _firstRssMb = 0;
    _lastRssMb = 0;
    _lastImageCacheMb = 0;
    _imageCacheMaxMb = 0;
    _lastImageCacheCount = 0;
    _lastLiveImages = 0;
  }

  /// Takes one sample; call on a timer (e.g. every 500ms).
  void sample() {
    var rss = 0.0;
    try {
      rss = ProcessInfo.currentRss / (1024 * 1024);
    } catch (_) {
      rss = 0;
    }
    _lastRssMb = rss;
    if (rss > 0) {
      if (_rssMb.isEmpty) _firstRssMb = rss;
      _rssMb.add(rss);
      if (_rssMb.length > _capacity) {
        _rssMb.removeRange(0, _rssMb.length - _capacity);
      }
    }

    final cache = PaintingBinding.instance.imageCache;
    _lastImageCacheMb = cache.currentSizeBytes / (1024 * 1024);
    _imageCacheMaxMb = cache.maximumSizeBytes / (1024 * 1024);
    _lastImageCacheCount = cache.currentSize;
    _lastLiveImages = cache.liveImageCount;
  }

  MemoryStats aggregate() {
    if (_rssMb.isEmpty) {
      return MemoryStats(
        rssMbAvg: 0,
        rssMbPeak: 0,
        rssMbStart: 0,
        rssMbEnd: _lastRssMb,
        imageCacheMb: _lastImageCacheMb,
        imageCacheMaxMb: _imageCacheMaxMb,
        imageCacheCount: _lastImageCacheCount,
        liveImages: _lastLiveImages,
      );
    }
    final sum = _rssMb.fold<double>(0, (a, b) => a + b);
    final peak = _rssMb.reduce((a, b) => a > b ? a : b);
    return MemoryStats(
      rssMbAvg: sum / _rssMb.length,
      rssMbPeak: peak,
      rssMbStart: _firstRssMb,
      rssMbEnd: _rssMb.last,
      imageCacheMb: _lastImageCacheMb,
      imageCacheMaxMb: _imageCacheMaxMb,
      imageCacheCount: _lastImageCacheCount,
      liveImages: _lastLiveImages,
    );
  }
}
