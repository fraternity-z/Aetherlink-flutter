import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

part 'multi_model_mentions_controller.g.dart';

/// The models staged for the next 多模型发送 (the port of the web message's
/// `mentions`). The 多模型发送 button opens a multi-select sheet and writes the
/// chosen `(provider, model)` pairs here; they show as chips above the composer
/// and the next [send] fans the turn out to all of them, then clears this.
///
/// Held purely in memory (session-only), mirroring the web where the pending
/// mention selection lives in component state, not persisted.
@Riverpod(keepAlive: true)
class MultiModelMentions extends _$MultiModelMentions {
  @override
  List<CurrentModel> build() => const <CurrentModel>[];

  /// Replaces the staged selection (e.g. after the multi-select sheet confirms).
  void set(List<CurrentModel> models) =>
      state = List<CurrentModel>.unmodifiable(models);

  /// Removes one staged model by `(providerId, modelId)` — the chip's ✕.
  void remove(String providerId, String modelId) => state =
      List<CurrentModel>.unmodifiable(
        state.where(
          (m) => !(m.provider.id == providerId && m.model.id == modelId),
        ),
      );

  void clear() => state = const <CurrentModel>[];
}
