import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// The header block of the 配置 Tab — rendered inline at the top of the shared
/// config card (no card of its own): a 48px brand avatar, the provider name, a
/// `{type} API` subtitle and (for non-system providers) edit-name / delete
/// icon buttons.
class ProviderHeader extends StatelessWidget {
  const ProviderHeader({
    super.key,
    required this.provider,
    required this.typeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final ModelProvider provider;
  final String typeLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final type = provider.providerType;
    final assetPath = getProviderIcon(
      (type != null && type.isNotEmpty) ? type : provider.id,
      isDark: isDark,
    );
    final fallback = provider.name.isNotEmpty
        ? provider.name.substring(0, 1).toUpperCase()
        : '?';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Center(
              child: Text(
                fallback,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$typeLabel API',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 18),
            color: theme.colorScheme.secondary,
            tooltip: '编辑名称 / 类型',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
          ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 18),
            color: theme.colorScheme.error,
            tooltip: '删除供应商',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
      ],
    );
  }
}

/// A compact tappable navigation row (icon + title + subtitle + chevron) used
/// inside the config card — e.g. the 高级 API 配置 entry — so a sub-page link
/// no longer needs its own heading + helper + button stack.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The base-URL completion preview — a tinted rounded line showing the full
/// endpoint (`getCompleteApiUrl`).
class UrlPreview extends StatelessWidget {
  const UrlPreview({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '完整端点',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            url,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Parameter scope row ─────────────────────────────────────────────────────

/// Dropdown for selecting the parameter display scope (parameterScope) at the
/// provider level. See `docs/PARAMETER_SCOPE_DESIGN.md`.
const List<(String?, String)> _parameterScopeOptions = [
  (null, '自动检测'),
  ('openai', 'OpenAI'),
  ('anthropic', 'Anthropic'),
  ('gemini', 'Gemini'),
  ('openaiCompatible', 'OpenAI 兼容'),
];

class ParameterScopeRow extends StatelessWidget {
  const ParameterScopeRow({
    super.key,
    required this.value,
    required this.labelStyle,
    required this.hintStyle,
    required this.onChanged,
  });

  final String? value;
  final TextStyle labelStyle;
  final TextStyle hintStyle;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('参数能力范围', style: labelStyle),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  '设置后，参数编辑器将按指定的模型家族显示可用参数，\n'
                  '覆盖自动检测结果。适用于第三方 API 转发场景。',
              child: Icon(LucideIcons.info, size: 15, color: hintStyle.color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppSelectField<String?>(
          value: _parameterScopeOptions.any((o) => o.$1 == value)
              ? value
              : null,
          sheetTitle: '参数能力范围',
          borderRadius: 12,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          options: [
            for (final option in _parameterScopeOptions)
              AppSelectOption<String?>(value: option.$1, label: option.$2),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        Text('设置此供应商下所有模型的参数显示范围（模型级设置优先）', style: hintStyle),
      ],
    );
  }
}
