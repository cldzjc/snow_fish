import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/geo_format.dart';

/// 用户常驻地区 / 雪场标签。
///
/// 只展示作者资料里的常驻信息，与帖子的发生地点无关。
/// 两项都为空时不占位。
class RegionTag extends StatelessWidget {
  const RegionTag({
    super.key,
    this.region,
    this.resort,
    this.plain = false,
    this.compact = false,
  });

  final String? region;
  final String? resort;

  /// true 时不加「常驻」前缀，用于紧凑位置。
  final bool plain;

  /// true 时只取「区县·雪场」，用于卡片右上角这类窄位置。
  final bool compact;

  static const String emptyResort = '暂无固定雪场';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = compact
        ? shortRegionLabel(region: region, resort: resort)
        : _fullLabel();
    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      style: AppText.meta.copyWith(color: colors.muted),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _fullLabel() {
    final r = region?.trim() ?? '';
    final s = resort?.trim() ?? '';
    final parts = <String>[
      if (r.isNotEmpty) r,
      if (s.isNotEmpty && s != emptyResort) s,
    ];
    if (parts.isEmpty) return '';
    final text = parts.join(' · ');
    return plain ? text : '常驻 $text';
  }
}
