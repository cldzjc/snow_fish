import 'package:flutter/material.dart';

import '../models/base_entity.dart';
import '../models/media_model.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import 'app/app_avatar.dart';
import 'app/app_icons.dart';
import 'app/app_sheet.dart';
import 'app/media_strip.dart';
import 'app/region_tag.dart';
import 'app/status_chip.dart';

/// 全站统一的帖子卡片。
///
/// 首页信息流、我的帖子、我的收藏、我的活动都使用这一份实现，
/// 只在「作者信息」「操作项」「右上角菜单」上按场景开关。
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.authorName,
    this.authorAvatar,
    this.region,
    this.resort,
    this.likeCount = 0,
    this.liked = false,
    this.showAuthor = true,
    this.showActions = true,
    this.showShare = true,
    this.showCommentAction = true,
    this.metaLine,
    this.statusText,
    this.onOpenDetail,
    this.onOpenProfile,
    this.onToggleLike,
    this.onOpenImage,
    this.onOpenVideo,
    this.onEdit,
    this.onDelete,
    this.excerptLines = 3,
  });

  final BaseEntity post;

  /// 作者昵称与头像；为空时只显示时间与地区标签。
  final String? authorName;
  final String? authorAvatar;
  final String? region;
  final String? resort;

  final int likeCount;
  final bool liked;
  final bool showAuthor;
  final bool showActions;
  final bool showShare;
  final bool showCommentAction;

  /// 额外的一行说明（活动时间、收藏来源等）。
  final String? metaLine;

  /// 活动状态胶囊文案。
  final String? statusText;

  final VoidCallback? onOpenDetail;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onToggleLike;
  final void Function(List<String> urls, int index)? onOpenImage;
  final void Function(MediaModel media)? onOpenVideo;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final int excerptLines;

  bool get _hasMenu => onEdit != null || onDelete != null;

  Future<void> _openMenu(BuildContext context) async {
    await showAppSheet<void>(
      context,
      title: '帖子操作',
      builder: (sheetContext) => Column(
        children: [
          _MenuTile(
            icon: AppIcons.share,
            label: '分享',
            onTap: () {
              Navigator.of(sheetContext).pop();
              ShareService.shareEntity(context, post);
            },
          ),
          if (onEdit != null)
            _MenuTile(
              icon: AppIcons.edit,
              label: '编辑',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onEdit!();
              },
            ),
          if (onDelete != null)
            _MenuTile(
              icon: AppIcons.trash,
              label: '删除',
              danger: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete!();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = (post.content ?? '').trim();
    final name = authorName?.trim();
    final displayName = (name == null || name.isEmpty) ? null : name;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.sm,
        AppSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAuthor)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: onOpenProfile != null,
                  label: displayName == null ? '作者' : '$displayName 的主页',
                  child: GestureDetector(
                    onTap: onOpenProfile,
                    child: AppAvatar(url: authorAvatar, size: AppSize.avatar),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (displayName != null)
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.title.copyWith(
                                    color: colors.ink,
                                  ),
                                ),
                              ),
                            if (displayName != null)
                              const SizedBox(width: AppSpace.sm),
                            Text(
                              TimeUtils.formatRelativeTime(post.createdAt),
                              style: AppText.meta.copyWith(color: colors.muted),
                            ),
                          ],
                        ),
                        if (region != null || resort != null) ...[
                          const SizedBox(height: AppSpace.xs),
                          RegionTag(region: region, resort: resort),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_hasMenu)
                  Semantics(
                    button: true,
                    label: '更多操作',
                    child: IconButton(
                      tooltip: '更多操作',
                      icon: Icon(AppIcons.more, color: colors.muted, size: 20),
                      onPressed: () => _openMenu(context),
                    ),
                  )
                else
                  const SizedBox(width: AppSpace.md),
              ],
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenDetail,
            child: Padding(
              padding: EdgeInsets.only(
                top: showAuthor ? AppSpace.md : 0,
                right: AppSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: AppText.title.copyWith(color: colors.ink),
                        ),
                      ),
                      if (statusText != null) ...[
                        const SizedBox(width: AppSpace.sm),
                        ActivityStatusChip(status: statusText!),
                      ],
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      content,
                      maxLines: excerptLines,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(color: colors.ink),
                    ),
                  ],
                  if (metaLine != null && metaLine!.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      metaLine!,
                      style: AppText.meta.copyWith(color: colors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            MediaStrip(
              media: post.media,
              onOpenImage: (urls, index) => onOpenImage?.call(urls, index),
              onOpenVideo: (media) => onOpenVideo?.call(media),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                if (onToggleLike != null)
                  _CardAction(
                    icon: liked ? AppIcons.heartFilled : AppIcons.heart,
                    label: likeCount > 0 ? '$likeCount' : '点赞',
                    active: liked,
                    onTap: onToggleLike!,
                  ),
                if (onToggleLike != null) const SizedBox(width: AppSpace.xl),
                if (showCommentAction)
                  _CardAction(
                    icon: AppIcons.comment,
                    label: post.commentCount > 0
                        ? '${post.commentCount}'
                        : '评论',
                    onTap: onOpenDetail,
                  ),
                if (showShare) ...[
                  const SizedBox(width: AppSpace.xl),
                  _CardAction(
                    icon: AppIcons.share,
                    label: '分享',
                    onTap: () => ShareService.shareEntity(context, post),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.danger : colors.muted;
    return Semantics(
      button: onTap != null,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppText.bodySmall.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = danger ? colors.danger : colors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpace.md),
            Text(label, style: AppText.body.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
