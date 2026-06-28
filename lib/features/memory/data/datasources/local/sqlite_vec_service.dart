import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vec/sqlite_vec.dart' as sqlite_vec;

import 'package:aetherlink_flutter/features/memory/domain/memory_vector.dart';

/// A memory id paired with its embedding, fed to [SqliteVecService.topKNearest].
typedef VecItem = ({String id, List<double> vector});

/// The outcome of probing for the sqlite-vec extension: whether it loaded and,
/// when it did, the reported `vec_version()`.
typedef VecProbe = ({bool available, String? version});

/// Experimental native-vector search via the sqlite-vec loadable extension.
///
/// **Fully optional and off by default.** Every method degrades to a `null` /
/// `false` result on any failure so callers fall back to the Dart-side cosine
/// path ([rankBySimilarity] / [rankByActivation]); nothing here ever throws.
///
/// sqlite-vec is a native library bundled per-platform by the `sqlite_vec`
/// plugin and is *not* linked into `flutter test` (no plugin registration), so
/// [probe] returns `available: false` there. Real availability can therefore
/// only be confirmed in an actual app build (真机 / 桌面) — which is exactly why
/// this is shipped behind a default-off flag with an in-app 「检测可用性」 probe.
class SqliteVecService {
  bool? _available;

  /// Probes whether the extension loads and answers `vec_version()` on this
  /// device. The result is cached after the first successful/failed attempt.
  /// Never throws.
  VecProbe probe() {
    if (_available == false) return (available: false, version: null);
    try {
      sqlite3.ensureExtensionLoaded(
        SqliteExtension.inLibrary(sqlite_vec.vec0, 'sqlite3_vec_init'),
      );
      final db = sqlite3.openInMemory();
      try {
        final version =
            db.select('SELECT vec_version() AS v').first['v'] as String?;
        _available = true;
        return (available: true, version: version);
      } finally {
        db.close();
      }
    } on Object {
      _available = false;
      return (available: false, version: null);
    }
  }

  /// Whether sqlite-vec is usable on this device (probing once if needed).
  bool get available => _available ?? probe().available;

  /// Native KNN: returns the ids of the [k] nearest [items] to [query], nearest
  /// first, or `null` when sqlite-vec is unavailable / the query fails — the
  /// signal for the caller to fall back to Dart cosine. Items whose vector
  /// length differs from [query] are skipped. Builds an ephemeral in-memory
  /// `vec0` index per call: this validates the native path end-to-end without
  /// touching the persistent Drift schema (no migration risk); persisting the
  /// index is a follow-up once on-device availability is confirmed.
  List<String>? topKNearest({
    required List<double> query,
    required List<VecItem> items,
    required int k,
  }) {
    if (query.isEmpty || items.isEmpty) return null;
    if (!available) return null;
    final dim = query.length;
    final limit = k < 1 ? 1 : k;
    Database? db;
    try {
      db = sqlite3.openInMemory();
      db.execute(
        'CREATE VIRTUAL TABLE v USING '
        'vec0(id TEXT PRIMARY KEY, embedding FLOAT[$dim])',
      );
      final insert = db.prepare('INSERT INTO v(id, embedding) VALUES (?, ?)');
      try {
        var inserted = 0;
        for (final item in items) {
          if (item.vector.length != dim) continue;
          insert.execute([item.id, float32Blob(item.vector)]);
          inserted++;
        }
        if (inserted == 0) return null;
      } finally {
        insert.close();
      }
      final rows = db.select(
        'SELECT id FROM v WHERE embedding MATCH ? ORDER BY distance LIMIT ?',
        [float32Blob(query), limit],
      );
      return [for (final row in rows) row['id'] as String];
    } on Object {
      return null;
    } finally {
      db?.close();
    }
  }
}
