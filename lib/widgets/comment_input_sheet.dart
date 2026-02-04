import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';

/// 评论输入底部弹窗
class CommentInputSheet extends StatefulWidget {
  final String entityId; // 帖子/商品ID
  final CommentModel? replyTo; // 回复的评论（null表示发布新评论）
  final Function(CommentModel) onCommentSubmitted;

  const CommentInputSheet({
    Key? key,
    required this.entityId,
    this.replyTo,
    required this.onCommentSubmitted,
  }) : super(key: key);

  @override
  State<CommentInputSheet> createState() => _CommentInputSheetState();
}

class _CommentInputSheetState extends State<CommentInputSheet> {
  final _contentController = TextEditingController();
  late final CommentService _commentService;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commentService = CommentService();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('评论内容不能为空')));
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final comment = await _commentService.createComment(
        entityId: widget.entityId,
        content: content,
        parentId: widget.replyTo?.id,
      );

      if (mounted) {
        widget.onCommentSubmitted(comment);
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('评论已发布')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReply = widget.replyTo != null;
    final replyToName = widget.replyTo?.authorNickname ?? '用户';

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 处理条
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题
          Text(
            isReply ? '回复 @$replyToName' : '写评论',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),

          // 输入框
          TextField(
            controller: _contentController,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              hintText: '说说你的想法...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          SizedBox(height: 12),

          // 发布按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey[300],
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      '发布${isReply ? '回复' : '评论'}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
