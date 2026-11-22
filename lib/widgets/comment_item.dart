import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import 'app/app_avatar.dart';
import 'app/app_icons.dart';
import 'app/app_sheet.dart';

/// 单条评论。回复以一层缩进展示。
class CommentItem extends StatefulWidget {
  const CommentItem({
    super.key,
    required this.comment,
    this.isReply = false,
    this.onReplyPressed,
    this.onDeleted,
    this.onChanged,
    this.onAuthorTap,
    this.onReportPressed,
  });

  final CommentModel comment;
  final bool isReply;
  final VoidCallback? onReplyPressed;
  final ValueChanged<CommentModel>? onDeleted;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onAuthorTap;
  final VoidCallback? onReportPressed;

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  final CommentService _commentService = CommentService();

  late bool _liked = widget.comment.userLiked;
  late int _likeCount = widget.comment.likeCount;
  bool _busy = false;

  bool get _isOwn =>
      widget.comment.userId == Supabase.instance.client.auth.currentUser?.id;

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _liked = !_liked;
      _likeCount = _liked
          ? _likeCount + 1
          : (_likeCount > 0 ? _likeCount - 1 : 0);
    });
    try {
      final result = await _commentService.toggleCommentLike(
        commentId: widget.comment.id,
      );
      if (!mounted) return;
      setState(() {
        _liked = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likeCount = _liked
            ? _likeCount + 1
            : (_likeCount > 0 ? _likeCount - 1 : 0);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('点赞失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMenu() async {
    await showAppSheet<void>(
      context,
      title: '评论操作',
      builder: (sheetContext) => Column(
        children: [
          if (_isOwn)
            _MenuRow(
              label: '编辑',
              onTap: () {
                Navigator.pop(sheetContext);
                _edit();
              },
            ),
          if (_isOwn)
            _MenuRow(
              label: '删除',
              danger: true,
              onTap: () {
                Navigator.pop(sheetContext);
                _delete();
              },
            ),
          _MenuRow(
            label: '举报',
            onTap: () {
              Navigator.pop(sheetContext);
              widget.onReportPressed?.call();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final controller = TextEditingController(text: widget.comment.content);
    final result = await showAppSheet<String>(
      context,
      title: '编辑评论',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            autofocus: true,
            style: AppText.body.copyWith(color: sheetContext.colors.ink),
            decoration: const InputDecoration(hintText: '写下你的想法…'),
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: () =>
                Navigator.pop(sheetContext, controller.text.trim()),
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    try {
      await _commentService.updateComment(
        commentId: widget.comment.id,
        content: result,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论已更新')));
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('编辑失败：$e')));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('删除后不可恢复，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _commentService.deleteComment(commentId: widget.comment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论已删除')));
      widget.onDeleted?.call(widget.comment);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.isReply ? AppSpace.xxl + AppSpace.lg : AppSpace.lg,
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: widget.isReply ? Colors.transparent : colors.line,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: '查看评论作者',
                child: GestureDetector(
                  onTap: () => widget.onAuthorTap?.call(widget.comment.userId),
                  child: AppAvatar(
                    url: widget.comment.authorAvatar,
                    size: AppSize.avatarSmall,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () =>
                                widget.onAuthorTap?.call(widget.comment.userId),
                            child: Text(
                              widget.comment.authorNickname
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? widget.comment.authorNickname!
                                  : '雪友',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodySmall.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          TimeUtils.formatRelativeTime(
                            widget.comment.createdAt,
                          ),
                          style: AppText.caption.copyWith(color: colors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      widget.comment.content,
                      style: AppText.body.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        _SmallAction(
                          icon: _liked ? AppIcons.heartFilled : AppIcons.heart,
                          label: _likeCount > 0 ? '$_likeCount' : '赞',
                          active: _liked,
                          onTap: _toggleLike,
                        ),
                        const SizedBox(width: AppSpace.lg),
                        _SmallAction(
                          icon: AppIcons.comment,
                          label: '回复',
                          onTap: widget.onReplyPressed ?? () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: '评论操作菜单',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: _openMenu,
                  child: SizedBox(
                    width: AppSize.tap,
                    height: AppSize.tap,
                    child: Icon(AppIcons.more, size: 18, color: colors.muted),
                  ),
                ),
              ),
            ],
          ),
          if (widget.comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSize.avatarSmall + AppSpace.sm,
                top: AppSpace.sm,
              ),
              child: Column(
                children: [
                  for (final reply in widget.comment.replies)
                    CommentItem(
                      key: ValueKey(reply.id),
                      comment: reply,
                      isReply: true,
                      onReplyPressed: widget.onReplyPressed,
                      onDeleted: widget.onDeleted,
                      onChanged: widget.onChanged,
                      onAuthorTap: widget.onAuthorTap,
                      onReportPressed: widget.onReportPressed,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.danger : colors.muted;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: AppText.caption.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Text(
          label,
          style: AppText.body.copyWith(
            color: danger ? colors.danger : colors.ink,
          ),
        ),
      ),
    );
  }
}
