import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 用户常驻地区 / 雪场标签。
///
/// 只展示作者资料里的常驻信息，与帖子的发生地点无关。
/// 两项都为空时不占位。
class RegionTag extends StatelessWidget {
  const RegionTag({super.key, this.region, this.resort, this.plain = false});

  final String? region;
  final String? resort;

  /// true 时不加「常驻」前缀，用于紧凑位置。
  final bool plain;

  static const String emptyResort = '暂无固定雪场';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = region?.trim() ?? '';
    final s = resort?.trim() ?? '';
    final parts = <String>[
      if (r.isNotEmpty) r,
      if (s.isNotEmpty && s != emptyResort) s,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    final text = parts.join(' · ');
    return Text(
      plain ? text : '常驻 $text',
      style: AppText.meta.copyWith(color: colors.muted),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
