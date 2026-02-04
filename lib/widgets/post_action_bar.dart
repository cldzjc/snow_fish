import 'package:flutter/material.dart';
import '../services/entity_service.dart';

/// 帖子操作栏组件 - 显示点赞爱心
class PostActionBar extends StatefulWidget {
  final String postId;
  final String userId;
  final Function(bool isLiked)? onLikeChanged;

  const PostActionBar({
    Key? key,
    required this.postId,
    required this.userId,
    this.onLikeChanged,
  }) : super(key: key);

  @override
  State<PostActionBar> createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  late final EntityService _entityService;
  int _likeCount = 0;
  bool _isLiked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _entityService = EntityService();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // 获取点赞统计
      final stats = await _entityService.getVoteStats(widget.postId);
      final hasLiked = await _entityService.hasVoted(
        entityId: widget.postId,
        score: 5,
      );

      if (mounted) {
        setState(() {
          _likeCount = stats['like_count'] ?? 0;
          _isLiked = hasLiked;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 加载统计数据失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    try {
      setState(() => _isLiked = !_isLiked);

      // 调用 EntityService 的 toggleVote 方法
      final result = await _entityService.toggleVote(
        entityId: widget.postId,
        score: 5,
      );

      if (result) {
        // 更新点赞数
        if (_isLiked) {
          _likeCount++;
        } else {
          _likeCount = (_likeCount - 1).clamp(0, double.infinity).toInt();
        }

        if (mounted) {
          setState(() {});
        }

        // 回调通知父组件
        widget.onLikeChanged?.call(_isLiked);
      } else {
        // 操作失败，恢复状态
        setState(() => _isLiked = !_isLiked);
      }
    } catch (e) {
      print('❌ 点赞操作失败: $e');
      // 恢复状态
      setState(() => _isLiked = !_isLiked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败: $e'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [SizedBox(height: 32)],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: GestureDetector(
        onTap: _toggleLike,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 爱心图标
            Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: _isLiked ? Colors.red[400] : Colors.grey[600],
            ),
            SizedBox(width: 6),
            // 点赞数
            Text(
              _likeCount > 0 ? _likeCount.toString() : '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
