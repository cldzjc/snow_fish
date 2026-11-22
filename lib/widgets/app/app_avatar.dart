import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// 圆形头像。
///
/// 无头像时退化为浅色底 + 人形图标，不会显示他人头像。
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.url, this.size = AppSize.avatar});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trimmed = url?.trim() ?? '';
    // 历史数据里存过 SVG 占位头像，Flutter 无法解码，统一退化为占位图标。
    final usable =
        trimmed.isNotEmpty && !trimmed.toLowerCase().contains('.svg');
    final iconSize = size * 0.46;

    final fallback = Container(
      width: size,
      height: size,
      color: colors.soft,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        size: iconSize,
        color: colors.muted,
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: usable
            ? CachedNetworkImage(
                imageUrl: trimmed,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: colors.soft),
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}
