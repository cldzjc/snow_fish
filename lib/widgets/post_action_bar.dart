import 'package:flutter/material.dart';

import '../services/entity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app/app_icons.dart';

/// 详情页操作栏：点赞与收藏。
///
/// 只负责这一个实体的状态，不缓存他人数据。
class PostActionBar extends StatefulWidget {
  const PostActionBar({super.key, required this.postId, this.onLikeChanged});

  final String postId;
  final ValueChanged<bool>? onLikeChanged;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('点赞失败：$e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('收藏失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 48);
    }
    return Row(
      children: [
        _Pill(
          icon: _liked ? AppIcons.heartFilled : AppIcons.heart,
          label: _likeCount > 0 ? '$_likeCount' : '点赞',
          active: _liked,
          activeColor: context.colors.danger,
          semanticLabel: _liked ? '取消点赞' : '点赞',
          onTap: _toggleLike,
        ),
        const SizedBox(width: AppSpace.xl),
        _Pill(
          icon: _favorite ? AppIcons.bookmarkFilled : AppIcons.bookmark,
          label: _favorite ? '已收藏' : '收藏',
          active: _favorite,
          activeColor: context.colors.ink,
          semanticLabel: _favorite ? '取消收藏' : '收藏',
          onTap: _toggleFavorite,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? activeColor : colors.muted;
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
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
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppText.bodySmall.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
