import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/media_url.dart';

/// 圆形头像。
///
/// 无头像时退化为浅色底 + 人形图标，不会显示他人头像。
/// 图片地址统一走 OSS 缩略图：原图动辄 1MB 以上，直接加载会长时间空白；
/// 历史数据里还有浏览器无法解码的 HEIC，需要 OSS 转成 JPEG 才能显示。
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
                imageUrl: avatarThumb(trimmed, size),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}
