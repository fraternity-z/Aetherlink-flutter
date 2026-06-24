import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

import 'local_backup_page.dart';
import 'cloud_backup_page.dart';
import 'import_data_page.dart';
import 'backup_reminder_page.dart';
import 'diagnostic_page.dart';

/// Entry page for data management / backup settings.
/// Shows a list of categories that navigate to detail pages (Level 2).
class BackupSettingsPage extends ConsumerWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '数据管理'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildSection(
            theme: theme,
            title: '备份与恢复',
            children: [
              _NavigationTile(
                icon: LucideIcons.hardDrive,
                title: '本地备份',
                subtitle: '创建/恢复本地 ZIP 备份文件',
                onTap: () => _push(context, const LocalBackupPage()),
              ),
              _NavigationTile(
                icon: LucideIcons.cloud,
                title: '云备份',
                subtitle: 'WebDAV / S3 云端同步',
                onTap: () => _push(context, const CloudBackupPage()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme: theme,
            title: '数据迁移',
            children: [
              _NavigationTile(
                icon: LucideIcons.download,
                title: '导入第三方数据',
                subtitle: '从 ChatboxAI / Cherry Studio 导入',
                onTap: () => _push(context, const ImportDataPage()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme: theme,
            title: '维护',
            children: [
              _NavigationTile(
                icon: LucideIcons.bell,
                title: '备份提醒',
                subtitle: state.reminderEnabled
                    ? '已开启 · 每 ${state.reminderIntervalDays} 天提醒'
                    : '未开启',
                onTap: () => _push(context, const BackupReminderPage()),
              ),
              _NavigationTile(
                icon: LucideIcons.database,
                title: '数据库诊断',
                subtitle: '检查数据完整性，修复孤立数据',
                onTap: () => _push(context, const DiagnosticPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return ModelSettingsCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => page,
      ),
    );
  }
}

/// A single navigation tile leading to a Level-2 page.
class _NavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(LucideIcons.chevronRight, size: 16),
      onTap: onTap,
    );
  }
}
