import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../utils/time_utils.dart';
import '../services/comment_service.dart';

/// 单条评论组件 - 显示评论内容、作者信息、点赞等
class CommentItem extends StatefulWidget {
  final CommentModel comment;
  final bool isReply; // 是否是回复（控制缩进）
  final VoidCallback? onReplyPressed; // 回复按钮回调
  final Function(CommentModel)? onDeleted; // 删除后的回调
  final VoidCallback? onLikeChanged; // 点赞状态变化回调

  const CommentItem({
    Key? key,
    required this.comment,
    this.isReply = false,
    this.onReplyPressed,
    this.onDeleted,
    this.onLikeChanged,
  }) : super(key: key);

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  late final CommentService _commentService;
  late bool _isLiked;
  late int _likeCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _commentService = CommentService();
    _isLiked = widget.comment.userLiked;
    _likeCount = widget.comment.likeCount;
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    try {
      final liked = await _commentService.hasCommentLiked(
        commentId: widget.comment.id,
      );
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    } catch (e) {
      print('❌ 加载点赞状态失败: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    try {
      setState(() {
        _isLoading = true;
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });

      final result = await _commentService.toggleCommentLike(
        commentId: widget.comment.id,
      );

      if (!result && _isLiked) {
        // 取消点赞失败，恢复状态
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
      }

      widget.onLikeChanged?.call();
    } catch (e) {
      print('❌ 点赞操作失败: $e');
      // 恢复状态
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败: $e'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteComment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除评论'),
        content: Text('确定要删除此评论吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      await _commentService.deleteComment(commentId: widget.comment.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('评论已删除')));
        widget.onDeleted?.call(widget.comment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        widget.comment.authorAvatar ??
        'https://api.dicebear.com/7.x/avataaars/svg?seed=${widget.comment.userId}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isReply ? 20 : 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: widget.isReply ? Colors.grey[50] : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者信息行
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.comment.authorNickname ?? '匿名用户',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      TimeUtils.formatRelativeTime(widget.comment.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              // 更多菜单
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(child: Text('删除'), value: 'delete'),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteComment();
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 8),

          // 评论内容
          Text(
            widget.comment.content,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 8),

          // 操作栏（点赞、回复）
          Row(
            children: [
              // 点赞按钮
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 16,
                      color: _isLiked ? Colors.blue : Colors.grey[600],
                    ),
                    SizedBox(width: 4),
                    Text(
                      '赞',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isLiked ? Colors.blue : Colors.grey[600],
                      ),
                    ),
                    if (_likeCount > 0) ...[
                      SizedBox(width: 2),
                      Text(
                        _likeCount.toString(),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 16),

              // 回复按钮
              GestureDetector(
                onTap: widget.onReplyPressed,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      '回复',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 回复列表（如果有）
          if (widget.comment.replies.isNotEmpty) ...[
            SizedBox(height: 8),
            Divider(height: 1),
            SizedBox(height: 8),
            ...widget.comment.replies.map((reply) {
              return CommentItem(
                comment: reply,
                isReply: true,
                onReplyPressed: widget.onReplyPressed,
                onDeleted: widget.onDeleted,
                onLikeChanged: widget.onLikeChanged,
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}
