import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/data/database_diagnostic_service.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Detail page for database diagnostics.
class DiagnosticPage extends ConsumerStatefulWidget {
  const DiagnosticPage({super.key});

  @override
  ConsumerState<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends ConsumerState<DiagnosticPage> {
  DiagnosticResult? _result;
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(backupControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '数据库诊断'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据库健康检查',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '检查数据库完整性，查找孤立数据并修复',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(LucideIcons.database, size: 18),
                    label: Text(_isRunning ? '诊断中...' : '运行诊断'),
                    onPressed: _isRunning
                        ? null
                        : () => _runDiagnostic(controller),
                  ),
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _buildResultCard(controller, theme),
          ],
        ],
      ),
    );
  }

  Future<void> _runDiagnostic(BackupController controller) async {
    setState(() => _isRunning = true);
    try {
      final result = await controller.runDiagnostic();
      if (mounted) {
        setState(() {
          _result = result;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('诊断失败: $e')),
        );
      }
    }
  }

  Widget _buildResultCard(BackupController controller, ThemeData theme) {
    final result = _result!;
    return ModelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isHealthy
                    ? LucideIcons.circleCheck
                    : LucideIcons.triangleAlert,
                color: result.isHealthy ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.isHealthy ? '数据库健康' : '发现问题',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _diagRow('数据库大小', result.databaseSizeDisplay),
          _diagRow('对话数', '${result.topicCount}'),
          _diagRow('消息数', '${result.messageCount}'),
          _diagRow('消息块数', '${result.messageBlockCount}'),
          _diagRow('服务商数', '${result.providerCount}'),
          _diagRow('助手数', '${result.assistantCount}'),
          _diagRow('分组数', '${result.groupCount}'),
          if (result.orphanedMessages > 0)
            _diagRow('孤立消息', '${result.orphanedMessages}', isWarning: true),
          if (result.orphanedBlocks > 0)
            _diagRow('孤立消息块', '${result.orphanedBlocks}', isWarning: true),
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('问题列表:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...result.issues.map((i) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $i',
                      style: const TextStyle(color: Colors.orange)),
                )),
          ],
          if (!result.isHealthy) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(LucideIcons.wrench, size: 18),
                label: const Text('修复'),
                onPressed: () => _performRepair(controller),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _performRepair(BackupController controller) async {
    setState(() => _isRunning = true);
    try {
      final result = await controller.repairDatabase();
      if (!mounted) return;
      setState(() => _isRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '修复完成: 清理了 ${result.orphanedMessagesRemoved} 条孤立消息, '
            '${result.orphanedBlocksRemoved} 个孤立消息块',
          ),
        ),
      );
      // Re-run diagnostic to refresh results
      _runDiagnostic(controller);
    } catch (e) {
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修复失败: $e')),
        );
      }
    }
  }

  Widget _diagRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isWarning ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }
}
