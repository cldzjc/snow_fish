import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum AppButtonVariant {
  /// 实心：主操作。
  solid,

  /// 描边：次操作。
  outline,

  /// 纯文字：低权重操作。
  text,

  /// 危险文字：删除类操作。
  danger,
}

/// 统一按钮。
///
/// 高度固定 48，圆角 12，禁用态自动降级；`loading` 时显示转圈并禁用点击。
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.solid,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  /// 更矮的按钮，用于行内操作。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null && !loading;
    final height = dense ? 38.0 : 48.0;

    late final Color background;
    late final Color foreground;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.solid:
        background = enabled ? colors.ink : colors.soft;
        foreground = enabled ? colors.paper : colors.muted;
      case AppButtonVariant.outline:
        background = Colors.transparent;
        foreground = enabled ? colors.ink : colors.muted;
        border = BorderSide(color: colors.line);
      case AppButtonVariant.text:
        background = Colors.transparent;
        foreground = enabled ? colors.ink : colors.muted;
      case AppButtonVariant.danger:
        background = Colors.transparent;
        foreground = enabled ? colors.danger : colors.muted;
    }

    final content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 17 : 18, color: foreground),
                const SizedBox(width: AppSpace.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.button.copyWith(color: foreground),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onPressed : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: border == BorderSide.none
                  ? null
                  : Border.fromBorderSide(border),
            ),
            child: Container(
              height: height,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: variant == AppButtonVariant.text ? AppSpace.sm : 14,
              ),
              width: expand ? double.infinity : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
