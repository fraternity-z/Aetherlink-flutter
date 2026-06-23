import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';

/// Self-contained parameter editor that can be embedded inline (sidebar settings
/// group) or displayed inside a dialog.
class ParameterEditor extends ConsumerStatefulWidget {
  const ParameterEditor({
    super.key,
    this.providerType,
    this.showCustomParameters = true,
  });

  /// When non-null only parameters for this provider are shown.
  final ProviderType? providerType;

  /// Whether to show the custom parameters section at the bottom.
  final bool showCustomParameters;

  @override
  ConsumerState<ParameterEditor> createState() => _ParameterEditorState();
}

class _ParameterEditorState extends ConsumerState<ParameterEditor> {
  bool _showApiKeys = false;

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(parameterSettingsControllerProvider);
    final ctrl = ref.read(parameterSettingsControllerProvider.notifier);

    final visibleParams = widget.providerType != null
        ? getParametersForProvider(widget.providerType!)
        : kParameterMetadata;

    // Group by category.
    final grouped = <ParameterCategory, List<ParameterMeta>>{};
    for (final p in visibleParams) {
      if (!_passesShowWhen(p, ps)) continue;
      (grouped[p.category] ??= []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // API key toggle header
        _buildHeader(),
        for (final cat in ParameterCategory.values)
          if (grouped.containsKey(cat)) ...[
            _CategoryHeader(label: categoryLabel(cat)),
            for (final meta in grouped[cat]!)
              _buildParameterRow(meta, ps, ctrl),
          ],
        if (widget.showCustomParameters) ...[
          const _CategoryHeader(label: '自定义参数'),
          _CustomParametersSection(ps: ps, ctrl: ctrl),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => setState(() => _showApiKeys = !_showApiKeys),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.code,
                size: 14,
                color: _showApiKeys
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _passesShowWhen(ParameterMeta meta, ParameterSettings ps) {
    final sw = meta.showWhen;
    if (sw == null) return true;
    final depEnabled = ps.isParameterEnabled(sw.key);
    if (!depEnabled) return false;
    final depValue = ps.getParameterValue(sw.key);
    return sw.values.contains(depValue);
  }

  Widget _buildParameterRow(
    ParameterMeta meta,
    ParameterSettings ps,
    ParameterSettingsController ctrl,
  ) {
    final enabled = ps.isParameterEnabled(meta.key);
    final value = ps.getParameterValue(meta.key);
    final title = _showApiKeys ? meta.key : meta.label;

    return _ParameterTile(
      title: title,
      description: meta.description,
      enabled: enabled,
      onEnabledChanged: (v) => ctrl.setParameterEnabled(meta.key, v),
      child: enabled ? _buildInput(meta, value, ctrl) : null,
    );
  }

  Widget _buildInput(
    ParameterMeta meta,
    Object? value,
    ParameterSettingsController ctrl,
  ) {
    return switch (meta.inputType) {
      ParameterInputType.slider => _SliderInput(
        meta: meta,
        value: _toDouble(value) ?? _toDouble(meta.defaultValue) ?? 0,
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
      ParameterInputType.number => _NumberInput(
        meta: meta,
        value: _toInt(value),
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
      ParameterInputType.select => _SelectInput(
        meta: meta,
        value: value,
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
      ParameterInputType.switchToggle => _SwitchInput(
        value: value == true,
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
      ParameterInputType.text => _TextInput(
        meta: meta,
        value: value?.toString() ?? '',
        onChanged: (v) => ctrl.setParameterValue(meta.key, v),
      ),
    };
  }

  static double? _toDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return null;
  }

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }
}

// ─── Category header ─────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Parameter tile ──────────────────────────────────────────────────────────

class _ParameterTile extends StatelessWidget {
  const _ParameterTile({
    required this.title,
    required this.description,
    required this.enabled,
    required this.onEnabledChanged,
    this.child,
  });

  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 24,
                child: FittedBox(
                  child: Switch(value: enabled, onChanged: onEnabledChanged),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
              child: child!,
            ),
        ],
      ),
    );
  }
}

// ─── Input widgets ───────────────────────────────────────────────────────────

class _SliderInput extends StatelessWidget {
  const _SliderInput({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final min = meta.rangeMin ?? 0;
    final max = meta.rangeMax ?? 1;
    final step = meta.rangeStep ?? 0.1;
    final divisions = ((max - min) / step).round().clamp(1, 10000);
    final clamped = value.clamp(min, max);

    // Format display value: use integer format when step >= 1.
    final display = step >= 1
        ? clamped.toInt().toString()
        : clamped.toStringAsFixed(
            step < 0.01
                ? 3
                : step < 0.1
                ? 2
                : 1,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: clamped,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                meta.unit != null ? '$display ${meta.unit}' : display,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (meta.marks != null && meta.marks!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final m in meta.marks!)
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NumberInput extends StatefulWidget {
  const _NumberInput({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(_NumberInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          hintText: widget.meta.label,
          hintStyle: const TextStyle(fontSize: 11),
        ),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          widget.onChanged(parsed);
        },
      ),
    );
  }
}

class _SelectInput extends StatelessWidget {
  const _SelectInput({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = meta.options ?? [];
    if (options.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: DropdownButtonFormField<Object>(
        initialValue: _resolveValue(value, options),
        isExpanded: true,
        isDense: true,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o.value, child: Text(o.label)),
        ],
        onChanged: (v) => onChanged(v),
      ),
    );
  }

  /// Ensures the current value matches one of the available options.
  Object? _resolveValue(Object? v, List<SelectOption> opts) {
    for (final o in opts) {
      if (o.value == v) return v;
      if (o.value.toString() == v.toString()) return o.value;
    }
    return opts.isNotEmpty ? opts.first.value : null;
  }
}

class _SwitchInput extends StatelessWidget {
  const _SwitchInput({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 24,
        child: FittedBox(
          child: Switch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final ParameterMeta meta;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TextInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          hintText: widget.meta.description,
          hintStyle: const TextStyle(fontSize: 11),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ─── Custom parameters section ───────────────────────────────────────────────

class _CustomParametersSection extends StatelessWidget {
  const _CustomParametersSection({required this.ps, required this.ctrl});

  final ParameterSettings ps;
  final ParameterSettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final params = ps.customParameters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < params.length; i++)
          _CustomParameterRow(
            param: params[i],
            onRemove: () => ctrl.removeCustomParameter(i),
            onUpdate: (p) => ctrl.updateCustomParameter(i, p),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OutlinedButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('添加参数', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加自定义参数', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '参数名',
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valueCtrl,
              decoration: const InputDecoration(labelText: '值', isDense: true),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ctrl.addCustomParameter({
                  'name': nameCtrl.text.trim(),
                  'value': _inferValue(valueCtrl.text),
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  static Object _inferValue(String raw) {
    if (raw.isEmpty) return '';
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    final n = num.tryParse(raw);
    if (n != null) return n;
    return raw;
  }
}

class _CustomParameterRow extends StatelessWidget {
  const _CustomParameterRow({
    required this.param,
    required this.onRemove,
    required this.onUpdate,
  });

  final Map<String, dynamic> param;
  final VoidCallback onRemove;
  final ValueChanged<Map<String, dynamic>> onUpdate;

  @override
  Widget build(BuildContext context) {
    final name = param['name']?.toString() ?? '';
    final value = param['value']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$name: $value',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.x,
                size: 14,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
