import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Detail page for local backup & restore operations.
class LocalBackupPage extends ConsumerStatefulWidget {
  const LocalBackupPage({super.key});

  @override
  ConsumerState<LocalBackupPage> createState() => _LocalBackupPageState();
}

class _LocalBackupPageState extends ConsumerState<LocalBackupPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupControllerProvider);
    final controller = ref.read(backupControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(backupControllerProvider, (prev, next) {
      if (next.status == BackupStatus.success ||
          next.status == BackupStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: next.status == BackupStatus.error
                ? theme.colorScheme.error
                : null,
          ),
        );
        Future.delayed(const Duration(seconds: 2), controller.clearStatus);
      }
    });

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '本地备份'),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _buildActionSection(controller, state, theme),
              const SizedBox(height: 16),
              _buildLocalBackupListSection(state, controller, theme),
            ],
          ),
          if (state.status == BackupStatus.working)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(state.message),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionSection(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备份与恢复',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '将数据导出为 ZIP 文件，或从备份文件恢复',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(LucideIcons.download, size: 18),
              label: const Text('创建备份'),
              onPressed: state.status == BackupStatus.working
                  ? null
                  : controller.createAndShareBackup,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.upload, size: 18),
              label: const Text('从文件恢复'),
              onPressed: state.status == BackupStatus.working
                  ? null
                  : () => _pickAndRestore(controller),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndRestore(BackupController controller) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    BackupManifest? manifest;
    try {
      manifest = await controller.pickAndPeekBackup();
    } catch (_) {}

    if (!mounted) return;

    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (context) => _RestoreConfirmDialog(manifest: manifest),
    );
    if (mode == null) return;

    await controller.restoreFromLocal(path, mode);
  }

  Widget _buildLocalBackupListSection(
    BackupState state,
    BackupController controller,
    ThemeData theme,
  ) {
    if (state.localBackups.isEmpty) return const SizedBox.shrink();

    return ModelSettingsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '本地备份历史',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...state.localBackups.map((item) => ListTile(
                dense: true,
                leading: Icon(
                  item.isAuto ? LucideIcons.shieldCheck : LucideIcons.archive,
                  size: 20,
                  color: item.isAuto
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
                title: Text(
                  item.displayName,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.sizeDisplay} | ${_formatDate(item.lastModified)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  onPressed: () =>
                      controller.deleteLocalBackup(item.displayName),
                ),
              )),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Restore confirmation dialog
// ---------------------------------------------------------------------------

class _RestoreConfirmDialog extends StatefulWidget {
  final BackupManifest? manifest;
  const _RestoreConfirmDialog({this.manifest});

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  RestoreMode _mode = RestoreMode.overwrite;

  @override
  Widget build(BuildContext context) {
    final manifest = widget.manifest;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('确认恢复数据？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (manifest != null) ...[
              Text('备份信息:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _infoRow('创建时间', manifest.createdAt.split('T').first),
              _infoRow('数据版本', 'v${manifest.schemaVersion}'),
              _infoRow('对话数', '${manifest.stats.topics}'),
              _infoRow('消息数', '${manifest.stats.messages}'),
              _infoRow('助手数', '${manifest.stats.assistants}'),
              const SizedBox(height: 16),
            ],
            Text('恢复模式:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            RadioListTile<RestoreMode>(
              title: const Text('覆盖模式'),
              subtitle: const Text('清空当前数据，完整恢复'),
              value: RestoreMode.overwrite,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<RestoreMode>(
              title: const Text('合并模式'),
              subtitle: const Text('保留当前数据，追加新内容'),
              value: RestoreMode.merge,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.shieldCheck,
                    size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '恢复前会自动备份当前数据',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _mode),
          child: const Text('确认恢复'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
