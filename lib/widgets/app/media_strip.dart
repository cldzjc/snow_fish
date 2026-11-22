import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_icons.dart';

/// 帖子 / 活动的媒体区：横向滑动，视频显示缩略图与播放角标。
class MediaStrip extends StatelessWidget {
  const MediaStrip({
    super.key,
    required this.media,
    required this.onOpenImage,
    required this.onOpenVideo,
    this.height = 240,
    this.itemWidthFactor = 0.92,
  });

  final List<MediaModel> media;
  final void Function(List<String> urls, int index) onOpenImage;
  final void Function(MediaModel media) onOpenVideo;
  final double height;
  final double itemWidthFactor;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final imageUrls = media
        .where((item) => item.mediaType != 'video')
        .map((item) => item.url)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final multiple = media.length > 1;
        final itemWidth = multiple
            ? constraints.maxWidth * itemWidthFactor
            : constraints.maxWidth;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: media.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (context, index) {
                  final item = media[index];
                  final isVideo = item.mediaType == 'video';
                  return Semantics(
                    button: true,
                    label: isVideo ? '播放视频' : '查看第 ${index + 1} 张图片',
                    child: GestureDetector(
                      onTap: () {
                        if (isVideo) {
                          onOpenVideo(item);
                        } else {
                          final innerIndex = imageUrls.indexOf(item.url);
                          onOpenImage(
                            imageUrls,
                            innerIndex < 0 ? 0 : innerIndex,
                          );
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: SizedBox(
                          width: itemWidth,
                          child: _Preview(item: item),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (multiple && media.every((item) => item.mediaType != 'video'))
                Positioned(
                  right: AppSpace.md,
                  bottom: AppSpace.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${media.length} 图',
                      style: AppText.caption.copyWith(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.item});

  final MediaModel item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isVideo = item.mediaType == 'video';
    final previewUrl = isVideo
        ? ((item.thumbnailUrl?.trim().isNotEmpty ?? false)
              ? item.thumbnailUrl!.trim()
              : null)
        : item.url.trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (previewUrl == null || previewUrl.isEmpty)
          Container(
            color: colors.soft,
            alignment: Alignment.center,
            child: Icon(AppIcons.video, color: colors.muted, size: 26),
          )
        else
          CachedNetworkImage(
            imageUrl: previewUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: colors.soft),
            errorWidget: (_, __, ___) => Container(
              color: colors.soft,
              alignment: Alignment.center,
              child: Icon(AppIcons.image, color: colors.muted, size: 24),
            ),
          ),
        if (isVideo)
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.play, color: Colors.white, size: 26),
            ),
          ),
      ],
    );
  }
}
