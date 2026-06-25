import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';

part 'notes_ai_access.g.dart';

/// App-level seam giving the notes feature one-shot LLM access for AI auto-rename
/// (notes can't import chat/settings application directly). Reuses the auxiliary
/// 标题模型 (title model), falling back to the current chat model.
@Riverpod(keepAlive: true)
NotesAiService notesAiService(Ref ref) => NotesAiService(ref);

class NotesAiService {
  const NotesAiService(this._ref);

  final Ref _ref;

  /// Generates a concise title for [content] using the auxiliary title model.
  /// Returns `null` when no model is configured or the model yields nothing.
  Future<String?> generateTitle(String content) async {
    final text = content.trim();
    if (text.isEmpty) return null;

    final aux = _ref.read(auxiliaryModelControllerProvider);
    final providers = await _ref.read(appModelProvidersProvider.future);
    final current =
        resolveAuxiliaryModel(aux.titleModelKey, providers) ??
        findCurrentModel(providers);
    if (current == null) return null;

    final effective = effectiveModelFor(current);
    final body = text.length > 2000 ? text.substring(0, 2000) : text;
    final prompt =
        '为下面的笔记内容生成一个简洁的标题。要求：不超过 20 个字；只返回标题本身；'
        '不要使用引号；不要以标点结尾；使用与正文相同的语言。\n\n笔记内容：\n$body';

    final request = LlmChatRequest(
      model: effective,
      messages: [LlmMessage(role: MessageRole.user, content: prompt)],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );
    final gateway = _ref.read(appLlmGatewayFactoryProvider).forModel(effective);

    final buffer = StringBuffer();
    await for (final chunk in gateway.streamChat(request)) {
      if (chunk is LlmTextDelta) buffer.write(chunk.text);
    }
    return _sanitize(buffer.toString());
  }

  /// Cleans the model output into a single-line, filename-safe title.
  String? _sanitize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    // First non-empty line.
    s = s
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => s)
        .trim();
    // Strip surrounding quote characters.
    const quotes = '"\'“”「」『』';
    while (s.isNotEmpty && quotes.contains(s[0])) {
      s = s.substring(1);
    }
    while (s.isNotEmpty && quotes.contains(s[s.length - 1])) {
      s = s.substring(0, s.length - 1);
    }
    s = s.trim();
    // Replace characters illegal in file names.
    s = s
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.length > 50) s = s.substring(0, 50).trim();
    return s.isEmpty ? null : s;
  }
}
