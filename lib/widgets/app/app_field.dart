import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 表单字段容器：字段名在上，控件在下。
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.child,
    this.requiredMark = false,
    this.note,
  });

  final String label;
  final Widget child;
  final bool requiredMark;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppText.label.copyWith(color: colors.muted)),
            if (requiredMark)
              Text(' *', style: AppText.label.copyWith(color: colors.danger)),
            if (note != null) ...[
              const SizedBox(width: AppSpace.sm),
              Text(note!, style: AppText.caption.copyWith(color: colors.muted)),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        child,
      ],
    );
  }
}

/// 单行/多行输入框。
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.autofocus = false,
    this.maxLength,
  });

  final TextEditingController? controller;
  final String? hint;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      autofocus: autofocus,
      maxLength: maxLength,
      cursorColor: colors.ink,
      style: AppText.body.copyWith(color: colors.ink),
      decoration: InputDecoration(
        hintText: hint,
        counterStyle: AppText.caption.copyWith(color: colors.muted),
      ),
    );
  }
}

/// 下拉选项。
class AppOption<T> {
  const AppOption(this.value, this.label);

  final T value;
  final String label;
}

/// 统一样式的下拉框。
///
/// 用 [DropdownButton] 而不是 [DropdownButtonFormField]，
/// 避免表单字段在值变化时被内部 state 冻结。
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  final List<AppOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasValue = options.any((option) => option.value == value);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: hasValue ? value : null,
          isExpanded: true,
          isDense: true,
          hint: Text(
            hint ?? '',
            style: AppText.body.copyWith(color: colors.muted),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: colors.muted,
          ),
          dropdownColor: colors.paper,
          borderRadius: BorderRadius.circular(AppRadius.md),
          style: AppText.body.copyWith(color: colors.ink),
          items: options
              .map(
                (option) => DropdownMenuItem<T>(
                  value: option.value,
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(color: colors.ink),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
