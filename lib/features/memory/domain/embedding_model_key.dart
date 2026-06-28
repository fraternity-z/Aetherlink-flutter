/// Encoding for [MemorySettings.embeddingModelKey] — a `(providerId, modelId)`
/// pair packed into one string with a NUL separator, matching the convention
/// the 辅助模型 settings use for their stored model keys. Kept in `memory/domain`
/// so both the settings UI (which writes it) and the composition root (which
/// resolves it) can share the codec without crossing feature boundaries.
const String _separator = '\u0000';

/// Packs [providerId] and [modelId] into a persisted embedding-model key.
String encodeEmbeddingModelKey(String providerId, String modelId) =>
    '$providerId$_separator$modelId';

/// Unpacks a stored key into `(providerId, modelId)`, or `null` when absent or
/// malformed.
(String providerId, String modelId)? decodeEmbeddingModelKey(String? key) {
  if (key == null || key.isEmpty) return null;
  final parts = key.split(_separator);
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
  return (parts[0], parts[1]);
}
