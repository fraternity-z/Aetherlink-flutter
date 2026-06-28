import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Compact toolbar chip for 获取 / 端点 / 添加 actions.
class CompactActionChip extends StatelessWidget {
  const CompactActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final base = accent ?? theme.colorScheme.primary;
    final color = enabled ? base : theme.disabledColor;

    return Material(
      color: enabled
          ? base.withValues(alpha: 0.1)
          : theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single toggle chip controlling whether each model row shows a 测试
/// (connection-test) button. The choice is persisted per provider, so it
/// survives navigation — no separate "test mode" vs "pin" distinction.
///
///  ┌─────────┐
///  │ 🧪 测试  │   (highlighted when active)
///  └─────────┘
class TestButtonChip extends StatelessWidget {
  const TestButtonChip({
    super.key,
    required this.active,
    required this.onToggle,
  });

  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : (theme.brightness == Brightness.dark
              ? const Color(0xFF66BB6A)
              : const Color(0xFF2E7D32));

    return Tooltip(
      message: active ? '隐藏每个模型的测试按钮' : '在每个模型上显示测试按钮',
      child: Material(
        color: color.withValues(alpha: active ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.flaskConical, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '测试',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
