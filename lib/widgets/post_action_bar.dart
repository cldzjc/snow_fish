import 'package:flutter/material.dart';

import '../services/entity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app/app_icons.dart';
import '../utils/error_text.dart';

/// 详情页操作栏：点赞 / 收藏 / 分享。
///
/// 图标式排版，不带文字，只保留点赞数。
class PostActionBar extends StatefulWidget {
  const PostActionBar({
    super.key,
    required this.postId,
    this.onLikeChanged,
    this.onShare,
  });

  final String postId;
  final ValueChanged<bool>? onLikeChanged;
  final VoidCallback? onShare;

  @override
  State<PostActionBar> createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  final EntityService _entityService = EntityService();

  int _likeCount = 0;
  bool _liked = false;
  bool _favorite = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await _entityService.getVoteStats(widget.postId);
      final liked = await _entityService.hasVoted(
        entityId: widget.postId,
        score: 5,
      );
      final favorite = await _entityService.hasFavorite(widget.postId);
      if (!mounted) return;
      setState(() {
        _likeCount = stats['like_count'] ?? 0;
        _liked = liked;
        _favorite = favorite;
        _loading = false;
      });
    } catch (e) {
      debugPrint('加载互动状态失败: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_busy || _loading) return;
    setState(() {
      _busy = true;
      _liked = !_liked;
      _likeCount = _liked
          ? _likeCount + 1
          : (_likeCount > 0 ? _likeCount - 1 : 0);
    });
    try {
      await _entityService.toggleVote(entityId: widget.postId, score: 5);
      widget.onLikeChanged?.call(_liked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likeCount = _liked
            ? _likeCount + 1
            : (_likeCount > 0 ? _likeCount - 1 : 0);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '点赞失败'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_busy || _loading) return;
    setState(() {
      _busy = true;
      _favorite = !_favorite;
    });
    try {
      final result = await _entityService.toggleFavorite(widget.postId);
      if (!mounted) return;
      setState(() => _favorite = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favorite = !_favorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '收藏失败'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 48);
    }
    final colors = context.colors;
    return Row(
      children: [
        _IconAction(
          icon: _liked ? AppIcons.heartFilled : AppIcons.heart,
          color: _liked ? colors.danger : colors.muted,
          semanticLabel: _liked ? '取消点赞' : '点赞',
          onTap: _toggleLike,
        ),
        if (_likeCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '$_likeCount',
              style: AppText.bodySmall.copyWith(
                color: _liked ? colors.danger : colors.muted,
              ),
            ),
          ),
        const SizedBox(width: AppSpace.xxl),
        _IconAction(
          icon: _favorite ? AppIcons.bookmarkFilled : AppIcons.bookmark,
          color: _favorite ? colors.ink : colors.muted,
          semanticLabel: _favorite ? '取消收藏' : '收藏',
          onTap: _toggleFavorite,
        ),
        const SizedBox(width: AppSpace.xxl),
        _IconAction(
          icon: AppIcons.share,
          color: colors.muted,
          semanticLabel: '分享',
          onTap: widget.onShare ?? () {},
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        radius: 22,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
