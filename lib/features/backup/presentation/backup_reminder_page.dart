import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Detail page for backup reminder settings.
class BackupReminderPage extends ConsumerStatefulWidget {
  const BackupReminderPage({super.key});

  @override
  ConsumerState<BackupReminderPage> createState() => _BackupReminderPageState();
}

class _BackupReminderPageState extends ConsumerState<BackupReminderPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupControllerProvider);
    final controller = ref.read(backupControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '备份提醒'),
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
                  '定期提醒',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '定期提醒你进行备份，保护数据安全',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('启用备份提醒'),
                  value: state.reminderEnabled,
                  onChanged: (v) async {
                    if (v && state.reminderMinutesOfDay == null) {
                      await controller.saveReminderSchedule(
                        enabled: true,
                        intervalDays: state.reminderIntervalDays,
                        minutesOfDay: 10 * 60,
                      );
                    } else {
                      await controller.setReminderEnabled(v);
                    }
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (state.reminderEnabled) ...[
                  const SizedBox(height: 12),
                  _buildIntervalSelector(controller, state, theme),
                  const SizedBox(height: 12),
                  _buildTimeSelector(controller, state, theme),
                  const SizedBox(height: 12),
                  if (state.lastBackupAt != null)
                    _reminderInfoRow(
                      theme,
                      '上次备份',
                      _formatDate(state.lastBackupAt),
                    ),
                  if (state.nextReminderAt != null)
                    _reminderInfoRow(
                      theme,
                      '下次提醒',
                      _formatDate(state.nextReminderAt),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Text('间隔: ', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: state.reminderIntervalDays,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('每天')),
              DropdownMenuItem(value: 3, child: Text('每 3 天')),
              DropdownMenuItem(value: 7, child: Text('每周')),
              DropdownMenuItem(value: 14, child: Text('每两周')),
              DropdownMenuItem(value: 30, child: Text('每月')),
            ],
            onChanged: (v) {
              if (v == null) return;
              controller.saveReminderSchedule(
                enabled: true,
                intervalDays: v,
                minutesOfDay: state.reminderMinutesOfDay ?? 10 * 60,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(
    BackupController controller,
    BackupState state,
    ThemeData theme,
  ) {
    final minutes = state.reminderMinutesOfDay ?? 10 * 60;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return Row(
      children: [
        Text('提醒时间: ', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked == null) return;
            final newMinutes = picked.hour * 60 + picked.minute;
            await controller.saveReminderSchedule(
              enabled: true,
              intervalDays: state.reminderIntervalDays,
              minutesOfDay: newMinutes,
            );
          },
          child: Text(time.format(context)),
        ),
      ],
    );
  }

  Widget _reminderInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
