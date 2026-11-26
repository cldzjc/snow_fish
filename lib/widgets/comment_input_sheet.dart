import 'package:flutter/material.dart';

import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app/app_sheet.dart';
import '../utils/error_text.dart';

/// 打开写评论 / 回复面板。成功时返回新建的评论，取消返回 null。
Future<CommentModel?> showCommentInputSheet(
  BuildContext context, {
  required String entityId,
  CommentModel? replyTo,
}) {
  final title = replyTo == null
      ? '写评论'
      : '回复 @${(replyTo.authorNickname?.trim().isNotEmpty ?? false) ? replyTo.authorNickname : '雪友'}';
  return showAppSheet<CommentModel>(
    context,
    title: title,
    builder: (_) => _CommentComposer(entityId: entityId, replyTo: replyTo),
  );
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({required this.entityId, this.replyTo});

  final String entityId;
  final CommentModel? replyTo;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final CommentService _commentService = CommentService();
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论内容不能为空')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final comment = await _commentService.createComment(
        entityId: widget.entityId,
        content: content,
        parentId: widget.replyTo?.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(comment);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论已发布')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '发布失败'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          style: AppText.body.copyWith(color: colors.ink),
          decoration: const InputDecoration(hintText: '写下你的想法…'),
        ),
        const SizedBox(height: AppSpace.xl),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: colors.paper,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.paper),
                    ),
                  )
                : const Text('发布评论'),
          ),
        ),
      ],
    );
  }
}
