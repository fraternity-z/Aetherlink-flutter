import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Detail page for cloud backup (WebDAV + S3).
class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});

  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _pathController;
  late final TextEditingController _s3EndpointController;
  late final TextEditingController _s3RegionController;
  late final TextEditingController _s3BucketController;
  late final TextEditingController _s3AccessKeyController;
  late final TextEditingController _s3SecretKeyController;
  late final TextEditingController _s3PrefixController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(backupControllerProvider);
    final config = state.webDavConfig;
    _urlController = TextEditingController(text: config.url);
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
    _pathController = TextEditingController(text: config.path);
    final s3 = state.s3Config;
    _s3EndpointController = TextEditingController(text: s3.endpoint);
    _s3RegionController = TextEditingController(text: s3.region);
    _s3BucketController = TextEditingController(text: s3.bucket);
    _s3AccessKeyController = TextEditingController(text: s3.accessKeyId);
    _s3SecretKeyController = TextEditingController(text: s3.secretAccessKey);
    _s3PrefixController = TextEditingController(text: s3.prefix);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    _s3EndpointController.dispose();
    _s3RegionController.dispose();
    _s3BucketController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3PrefixController.dispose();
    super.dispose();
  }

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
      appBar: const ModelSettingsAppBar(title: '云备份'),
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
              _buildWebDavSection(controller, state, theme),
              const SizedBox(height: 16),
              _buildS3Section(controller, state, theme),
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

  // ---------------------------------------------------------------------------
  // WebDAV section
  // ---------------------------------------------------------------------------

  Widget _buildWebDavSection(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WebDAV',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://dav.example.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            obscureText: true,
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: '备份路径',
              hintText: 'aetherlink_backups',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveWebDavConfig(controller),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.wifi, size: 18),
                  label: const Text('测试连接'),
                  onPressed: state.status == BackupStatus.working
                      ? null
                      : controller.testWebDavConnection,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(LucideIcons.cloudUpload, size: 18),
                  label: const Text('备份'),
                  onPressed: state.status == BackupStatus.working ||
                          !state.webDavConfig.isConfigured
                      ? null
                      : controller.backupToWebDav,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.cloudDownload, size: 18),
              label: const Text('从 WebDAV 恢复'),
              onPressed: state.status == BackupStatus.working ||
                      !state.webDavConfig.isConfigured
                  ? null
                  : () => _showRemoteFileList(controller),
            ),
          ),
        ],
      ),
    );
  }

  void _saveWebDavConfig(BackupController controller) {
    controller.updateWebDavConfig(WebDavConfig(
      url: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      path: _pathController.text.isEmpty
          ? 'aetherlink_backups'
          : _pathController.text,
    ));
  }

  Future<void> _showRemoteFileList(BackupController controller) async {
    await controller.loadRemoteBackups();
    if (!mounted) return;

    final state = ref.read(backupControllerProvider);
    if (state.remoteBackups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('远程没有备份文件')),
      );
      return;
    }

    final selected = await showModalBottomSheet<BackupFileItem>(
      context: context,
      builder: (context) => _RemoteFileListSheet(files: state.remoteBackups),
    );
    if (selected == null || !mounted) return;

    final mode = await _showRestoreDialog();
    if (mode == null) return;

    await controller.restoreFromWebDav(selected, mode);
  }

  // ---------------------------------------------------------------------------
  // S3 section
  // ---------------------------------------------------------------------------

  Widget _buildS3Section(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'S3 云存储',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支持 AWS S3、Cloudflare R2、MinIO 等兼容服务',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _s3EndpointController,
            decoration: const InputDecoration(
              labelText: 'Endpoint',
              hintText: 'https://s3.amazonaws.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _s3RegionController,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    hintText: 'us-east-1',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveS3Config(controller),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _s3BucketController,
                  decoration: const InputDecoration(
                    labelText: 'Bucket',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveS3Config(controller),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _s3AccessKeyController,
            decoration: const InputDecoration(
              labelText: 'Access Key ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _s3SecretKeyController,
            decoration: const InputDecoration(
              labelText: 'Secret Access Key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            obscureText: true,
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _s3PrefixController,
            decoration: const InputDecoration(
              labelText: '前缀/目录',
              hintText: 'aetherlink_backups',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _saveS3Config(controller),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Path Style'),
            subtitle: const Text('自托管/MinIO 推荐开启'),
            value: state.s3Config.pathStyle,
            onChanged: (v) {
              controller.updateS3Config(state.s3Config.copyWith(pathStyle: v));
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.wifi, size: 18),
                  label: const Text('测试连接'),
                  onPressed: state.status == BackupStatus.working
                      ? null
                      : controller.testS3Connection,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(LucideIcons.cloudUpload, size: 18),
                  label: const Text('备份'),
                  onPressed: state.status == BackupStatus.working ||
                          !state.s3Config.isConfigured
                      ? null
                      : controller.backupToS3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.cloudDownload, size: 18),
              label: const Text('从 S3 恢复'),
              onPressed: state.status == BackupStatus.working ||
                      !state.s3Config.isConfigured
                  ? null
                  : () => _showS3FileList(controller),
            ),
          ),
        ],
      ),
    );
  }

  void _saveS3Config(BackupController controller) {
    controller.updateS3Config(S3Config(
      endpoint: _s3EndpointController.text,
      region: _s3RegionController.text.isEmpty
          ? 'us-east-1'
          : _s3RegionController.text,
      bucket: _s3BucketController.text,
      accessKeyId: _s3AccessKeyController.text,
      secretAccessKey: _s3SecretKeyController.text,
      prefix: _s3PrefixController.text.isEmpty
          ? 'aetherlink_backups'
          : _s3PrefixController.text,
      pathStyle: ref.read(backupControllerProvider).s3Config.pathStyle,
    ));
  }

  Future<void> _showS3FileList(BackupController controller) async {
    await controller.loadS3Backups();
    if (!mounted) return;

    final state = ref.read(backupControllerProvider);
    if (state.s3Backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('S3 没有备份文件')),
      );
      return;
    }

    final selected = await showModalBottomSheet<BackupFileItem>(
      context: context,
      builder: (context) => _RemoteFileListSheet(files: state.s3Backups),
    );
    if (selected == null || !mounted) return;

    final mode = await _showRestoreDialog();
    if (mode == null) return;

    await controller.restoreFromS3(selected, mode);
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Future<RestoreMode?> _showRestoreDialog() {
    return showDialog<RestoreMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择恢复模式'),
        content: const Text('覆盖模式会清除现有数据再恢复；\n合并模式会保留现有数据，仅添加新数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, RestoreMode.merge),
            child: const Text('合并'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, RestoreMode.overwrite),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Remote file list bottom sheet
// ---------------------------------------------------------------------------

class _RemoteFileListSheet extends StatelessWidget {
  final List<BackupFileItem> files;
  const _RemoteFileListSheet({required this.files});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '选择要恢复的备份',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final item = files[index];
                return ListTile(
                  leading: const Icon(LucideIcons.fileArchive, size: 20),
                  title: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.sizeDisplay} | ${_formatDate(item.lastModified)}',
                  ),
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
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
