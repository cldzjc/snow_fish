import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 活动状态芯片。
///
/// 数据里存英文状态值，这里统一映射成中文并给出视觉区分。
class ActivityStatusChip extends StatelessWidget {
  const ActivityStatusChip({super.key, required this.status});

  /// recruiting / full / ended / cancelled
  final String? status;

  static String labelOf(String? status) {
    return switch (status) {
      'recruiting' => '招募中',
      'full' => '已满员',
      'ended' => '已结束',
      'cancelled' => '已取消',
      _ => '招募中',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = status ?? 'recruiting';

    final Color background;
    final Color foreground;
    final Color border;
    switch (value) {
      case 'recruiting':
        background = colors.ink;
        foreground = colors.paper;
        border = colors.ink;
      case 'full':
        background = Colors.transparent;
        foreground = colors.ink;
        border = colors.muted;
      case 'ended':
        background = colors.soft;
        foreground = colors.muted;
        border = colors.soft;
      case 'cancelled':
        background = Colors.transparent;
        foreground = colors.muted;
        border = colors.line;
      default:
        background = colors.soft;
        foreground = colors.muted;
        border = colors.soft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        labelOf(value),
        style: AppText.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
