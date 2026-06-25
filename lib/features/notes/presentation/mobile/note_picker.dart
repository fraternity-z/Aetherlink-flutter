import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';

/// Shows a modal note browser and resolves with the chosen note ([NoteNode]),
/// or `null` if dismissed. Self-contained (its own folder navigation) so it
/// doesn't disturb the main browser's position.
Future<NoteNode?> showNotePicker(BuildContext context) {
  return showModalBottomSheet<NoteNode>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.72,
      child: _NotePicker(),
    ),
  );
}

class _NotePicker extends ConsumerStatefulWidget {
  const _NotePicker();

  @override
  ConsumerState<_NotePicker> createState() => _NotePickerState();
}

class _NotePickerState extends ConsumerState<_NotePicker> {
  String _path = '';
  List<NoteNode> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await ref.read(notesFileStoreProvider).list(_path);
    final sorted = [...raw]..sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    if (!mounted) return;
    setState(() {
      _items = sorted;
      _loading = false;
    });
  }

  void _goUp() {
    if (_path.isEmpty) return;
    _path = _path.contains('/')
        ? _path.substring(0, _path.lastIndexOf('/'))
        : '';
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              if (_path.isNotEmpty)
                IconButton(
                  icon: const Icon(LucideIcons.arrowLeft, size: 20),
                  onPressed: _goUp,
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _path.isEmpty ? '选择笔记' : _path.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? Center(
                  child: Text(
                    '此文件夹没有笔记',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final node = _items[index];
                    return ListTile(
                      leading: Icon(
                        node.isDirectory
                            ? LucideIcons.folder
                            : LucideIcons.fileText,
                        color: node.isDirectory
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF3B82F6),
                      ),
                      title: Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: node.isDirectory
                          ? const Icon(LucideIcons.chevronRight, size: 18)
                          : null,
                      onTap: () {
                        if (node.isDirectory) {
                          setState(() => _path = node.relativePath);
                          _load();
                        } else {
                          Navigator.pop(context, node);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
