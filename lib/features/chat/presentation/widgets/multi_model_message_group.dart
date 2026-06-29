import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';

/// Lays out a multi-model 兄弟组 (assistant replies sharing one `siblingsGroupId`)
/// as a comparison block — the Flutter analogue of the web `MultiModelMessageGroup`
/// and cherry-studio's `MessageGroup`.
///
/// The layout follows the 多模型布局 setting ([MultiModelDisplayStyle]) with a
/// per-group toggle:
///  * **horizontal** — cards scroll side by side (default for 2+ models);
///  * **vertical** — cards stacked top to bottom;
///  * **single** — only the selected model is shown (fold).
///
/// Following both references, each cell is just the real [ChatMessageBubble] (the
/// model name comes from the bubble's own header/footer — no duplicate per-card
/// header); model identity and 采用(选定) live only in the menu bar's model-chip
/// list, where tapping a chip continues the conversation from that reply
/// ([ChatController.selectSibling]).
class MultiModelMessageGroup extends ConsumerStatefulWidget {
  const MultiModelMessageGroup({super.key, required this.memberIds});

  /// The grouped assistant message ids, in display (chronological) order.
  final List<String> memberIds;

  @override
  ConsumerState<MultiModelMessageGroup> createState() =>
      _MultiModelMessageGroupState();
}

class _MultiModelMessageGroupState
    extends ConsumerState<MultiModelMessageGroup> {
  /// Per-group layout override (null = follow the global 多模型布局 setting).
  MultiModelDisplayStyle? _style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = widget.memberIds;
    final globalStyle = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.multiModelDisplayStyle),
    );
    final style = _style ?? globalStyle;

    // The selected sibling id (the one the conversation continues from).
    final selectedId = ref.watch(
      chatControllerProvider.select((a) {
        for (final id in members) {
          if (a.messageById(id)?.foldSelected ?? false) return id;
        }
        return members.isEmpty ? null : members.first;
      }),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _menuBar(theme, style, members, selectedId),
            _body(theme, style, members, selectedId),
          ],
        ),
      ),
    );
  }

  /// The group menu bar: a layout toggle and the model-chip list (model name +
  /// selected highlight; tap = 采用). Mirrors the references' `MenuBar` /
  /// `MessageGroupMenuBar`, but the chip list shows in every layout so 采用 stays
  /// reachable (the references only show it in fold).
  Widget _menuBar(
    ThemeData theme,
    MultiModelDisplayStyle style,
    List<String> members,
    String? selectedId,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '多模型对比 · ${members.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _styleButton(theme, style, MultiModelDisplayStyle.horizontal,
                  Icons.view_week, '横向'),
              _styleButton(theme, style, MultiModelDisplayStyle.vertical,
                  Icons.view_agenda, '纵向'),
              _styleButton(theme, style, MultiModelDisplayStyle.single,
                  Icons.crop_square, '单栏'),
            ],
          ),
          const SizedBox(height: 2),
          // Model chips: identify each model and pick which one the conversation
          // continues from (采用). In 单栏 layout this also drives which cell shows.
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final id in members)
                _ModelChip(
                  messageId: id,
                  selected: id == selectedId,
                  onTap: () => ref
                      .read(chatControllerProvider.notifier)
                      .selectSibling(id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _styleButton(
    ThemeData theme,
    MultiModelDisplayStyle current,
    MultiModelDisplayStyle value,
    IconData icon,
    String tooltip,
  ) {
    final active = current == value;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: active
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      onPressed: () => setState(() => _style = value),
      icon: Icon(icon),
    );
  }

  Widget _body(
    ThemeData theme,
    MultiModelDisplayStyle style,
    List<String> members,
    String? selectedId,
  ) {
    switch (style) {
      case MultiModelDisplayStyle.vertical:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final id in members)
              _MemberCell(messageId: id, selected: id == selectedId),
          ],
        );
      case MultiModelDisplayStyle.horizontal:
        final cardWidth = MediaQuery.of(context).size.width * 0.82;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final id in members)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardWidth),
                    child: _MemberCell(
                      messageId: id,
                      selected: id == selectedId,
                    ),
                  ),
              ],
            ),
          ),
        );
      case MultiModelDisplayStyle.single:
        // Fold: show only the selected sibling; the chip list switches it.
        final shownId = selectedId ?? members.first;
        return _MemberCell(messageId: shownId, selected: true);
    }
  }
}

/// A single grouped reply: the real [ChatMessageBubble] in a card whose border
/// highlights when it is the selected sibling. No model header — the bubble shows
/// its own model name, and selection lives in the menu bar's chip list.
class _MemberCell extends StatelessWidget {
  const _MemberCell({required this.messageId, required this.selected});

  final String messageId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: selected ? 1.5 : 1,
        ),
        color: theme.colorScheme.surface,
      ),
      child: ChatMessageBubble(key: ValueKey(messageId), messageId: messageId),
    );
  }
}

/// A model chip in the menu bar: the model name, a check when it is the selected
/// sibling, tap = 采用 (continue from this reply).
class _ModelChip extends ConsumerWidget {
  const _ModelChip({
    required this.messageId,
    required this.selected,
    required this.onTap,
  });

  final String messageId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modelName = ref.watch(
      chatControllerProvider.select(
        (a) => a.messageById(messageId)?.modelName,
      ),
    );
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: selected
          ? Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
          : null,
      label: Text(modelName ?? '模型', style: theme.textTheme.bodySmall),
    );
  }
}
