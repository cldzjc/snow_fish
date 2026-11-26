import 'package:flutter/material.dart';

import '../models/base_entity.dart';
import '../models/media_model.dart';
import '../services/circle_repository.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/geo_format.dart';
import '../utils/time_utils.dart';
import 'app/app_avatar.dart';
import 'app/app_icons.dart';
import 'app/app_sheet.dart';
import 'app/media_strip.dart';
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

  /// 正文若以标题开头（老数据或用户自己重复输入），摘要里去掉这段，避免重复。
  static String _excerptWithoutTitle(BaseEntity post) {
    final content = (post.content ?? '').trim();
    if (content.isEmpty) return content;
    final title = post.title.trim();
    if (title.isEmpty) return content;
    if (content == title) return '';
    if (content.startsWith(title)) {
      return content.substring(title.length).trimLeft();
    }
    return content;
  }

  /// 卡片右上角的位置：优先用发布时记下的地点，老帖子退回作者常驻地区。
  String? get _cardRegion =>
      (post.extraData['region_id'] as String?)?.trim().isNotEmpty == true
      ? post.extraData['region_id'] as String
      : region;

  String? get _cardResort =>
      (post.extraData['resort_id'] as String?)?.trim().isNotEmpty == true
      ? post.extraData['resort_id'] as String
      : resort;

  /// 右上角实际要显示的文案；为空时不占位。
  ///
  /// 圈内帖子显示圈子名（富龙圈 / 崇礼圈），sk社区的帖子显示区县·雪场。
  String get _regionLabel {
    final circleTag = CircleRepository.instance.tagFor(post.circleId);
    if (circleTag != null && circleTag.isNotEmpty) return circleTag;
    return shortRegionLabel(region: _cardRegion, resort: _cardResort);
  }

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
    final name = authorName?.trim();
    final displayName = (name == null || name.isEmpty) ? null : name;
    final content = _excerptWithoutTitle(post);

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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (displayName != null)
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title.copyWith(color: colors.ink),
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
                  ),
                ),
                if (_regionLabel.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: _CardTag(label: _regionLabel),
                  ),
                ],
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
            )
          else if (!showAuthor && (_regionLabel.isNotEmpty || _hasMenu))
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  const Spacer(),
                  if (_regionLabel.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: _CardTag(label: _regionLabel),
                    ),
                  if (_hasMenu)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpace.xs),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 30,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: '更多操作',
                        icon: Icon(
                          AppIcons.more,
                          color: colors.muted,
                          size: 20,
                        ),
                        onPressed: () => _openMenu(context),
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
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
                    semanticsLabel: '点赞',
                    count: likeCount > 0 ? '$likeCount' : null,
                    active: liked,
                    onTap: onToggleLike!,
                  ),
                if (onToggleLike != null) const SizedBox(width: AppSpace.md),
                if (showCommentAction)
                  _CardAction(
                    icon: AppIcons.comment,
                    semanticsLabel: '评论',
                    count: post.commentCount > 0
                        ? '${post.commentCount}'
                        : null,
                    onTap: onOpenDetail,
                  ),
                if (showShare) ...[
                  const SizedBox(width: AppSpace.md),
                  _CardAction(
                    icon: AppIcons.share,
                    semanticsLabel: '分享',
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

/// 卡片右上角的位置 / 圈子标签。
class _CardTag extends StatelessWidget {
  const _CardTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.meta.copyWith(color: colors.muted),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.count,
    this.active = false,
  });

  final IconData icon;
  final String semanticsLabel;
  final String? count;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.danger : colors.muted;
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: AppSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(count!, style: AppText.bodySmall.copyWith(color: color)),
              ],
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
