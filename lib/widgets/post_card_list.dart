import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../models/media_model.dart';
import '../pages/image_gallery_page.dart';
import '../pages/post_detail_page.dart';
import '../pages/profile_page.dart';
import '../pages/video_player_page.dart';
import '../services/entity_service.dart';
import '../services/my_profile_store.dart';
import '../theme/app_spacing.dart';
import 'post_card.dart';

/// 统一的帖子卡片列表。
///
/// 首页、我的帖子、我的收藏、他人主页都通过它渲染 [PostCard]，
/// 由它集中处理作者资料、点赞数、点赞状态和跳转，避免各处实现不一致。
class PostCardList extends StatefulWidget {
  const PostCardList({
    super.key,
    required this.posts,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
    this.footer,
    this.showAuthor = true,
    this.showActions = true,
    this.excerptLines = 3,
    this.statusTextOf,
    this.metaLineOf,
    this.onOpenDetail,
    this.onEdit,
    this.onDelete,
  });

  final List<BaseEntity> posts;
  final ScrollController? controller;
  final EdgeInsets padding;

  /// true 时用 Column 渲染，便于嵌在别的滚动视图里。
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Widget? footer;

  final bool showAuthor;
  final bool showActions;
  final int excerptLines;

  /// 活动状态胶囊文案。
  final String? Function(BaseEntity post)? statusTextOf;

  /// 卡片里额外的一行说明。
  final String? Function(BaseEntity post)? metaLineOf;

  /// 自定义「打开详情」行为；为空时跳转帖子详情页。
  final void Function(BaseEntity post)? onOpenDetail;

  final void Function(BaseEntity post)? onEdit;
  final void Function(BaseEntity post)? onDelete;

  @override
  State<PostCardList> createState() => _PostCardListState();
}

class _PostCardListState extends State<PostCardList> {
  final EntityService _entityService = EntityService();
  final Map<String, Map<String, dynamic>> _profileCache = {};
  final Map<String, int> _likeCounts = {};
  final Set<String> _likedIds = {};
  final Set<String> _likeInFlight = {};

  bool _profilesLoading = false;

  @override
  void initState() {
    super.initState();
    MyProfileStore.changedTick.addListener(_onMyProfileChanged);
    _syncData();
  }

  @override
  void dispose() {
    MyProfileStore.changedTick.removeListener(_onMyProfileChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PostCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.posts.map((item) => item.id).join(',');
    final after = widget.posts.map((item) => item.id).join(',');
    if (before != after) _syncData();
  }

  /// 自己的资料变了（例如改了常驻地区），作者信息要跟着刷新。
  void _onMyProfileChanged() {
    if (!mounted) return;
    final myId = MyProfileStore.userId;
    if (myId != null) _profileCache.remove(myId);
    _syncData();
  }

  Future<void> _syncData() async {
    final posts = widget.posts;
    if (posts.isEmpty) return;
    await Future.wait<void>([_loadProfiles(posts), _loadLikeStats(posts)]);
  }

  Future<void> _loadProfiles(List<BaseEntity> posts) async {
    final userIds = posts.map((post) => post.userId).toSet();
    final missing = userIds
        .where((userId) => !_profileCache.containsKey(userId))
        .toList();
    if (missing.isEmpty || !mounted) return;

    setState(() => _profilesLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .inFilter('id', missing);
      for (final profile in response as List) {
        final map = Map<String, dynamic>.from(profile as Map);
        final id = map['id'] as String?;
        if (id != null) _profileCache[id] = map;
      }
    } catch (e) {
      debugPrint('加载作者资料失败: $e');
    } finally {
      if (mounted) setState(() => _profilesLoading = false);
    }
  }

  Future<void> _loadLikeStats(List<BaseEntity> posts) async {
    final ids = posts.map((item) => item.id).toList();
    if (ids.isEmpty) return;
    try {
      final counts = await _entityService.fetchLikeCounts(ids);
      final liked = await _entityService.fetchLikedEntityIds(ids);
      if (!mounted) return;
      setState(() {
        _likeCounts.addAll(counts);
        _likedIds.addAll(liked);
      });
    } catch (e) {
      debugPrint('加载点赞统计失败: $e');
    }
  }

  Future<void> _toggleLike(BaseEntity post) async {
    if (_likeInFlight.contains(post.id)) return;
    _likeInFlight.add(post.id);
    final likedBefore = _likedIds.contains(post.id);
    final countBefore = _likeCounts[post.id] ?? 0;
    setState(() {
      if (likedBefore) {
        _likedIds.remove(post.id);
        _likeCounts[post.id] = countBefore > 0 ? countBefore - 1 : 0;
      } else {
        _likedIds.add(post.id);
        _likeCounts[post.id] = countBefore + 1;
      }
    });
    try {
      await _entityService.toggleVote(entityId: post.id, score: 5);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (likedBefore) {
          _likedIds.add(post.id);
        } else {
          _likedIds.remove(post.id);
        }
        _likeCounts[post.id] = countBefore;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      _likeInFlight.remove(post.id);
    }
  }

  void _openDetail(BaseEntity post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: post.id)),
    );
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  String _authorName(BaseEntity post) {
    final nickname = (_profileCache[post.userId]?['nickname'] as String?)
        ?.trim();
    if (nickname == null || nickname.isEmpty) {
      return _profilesLoading || _profileCache[post.userId] == null
          ? '加载资料…'
          : '雪友';
    }
    return nickname;
  }

  Widget _buildCard(BaseEntity post) {
    final profile = _profileCache[post.userId];
    return PostCard(
      post: post,
      authorName: _authorName(post),
      authorAvatar: profile?['avatar_url'] as String?,
      likeCount: _likeCounts[post.id] ?? 0,
      liked: _likedIds.contains(post.id),
      showAuthor: widget.showAuthor,
      showActions: widget.showActions,
      excerptLines: widget.excerptLines,
      statusText: widget.statusTextOf?.call(post),
      metaLine: widget.metaLineOf?.call(post),
      onOpenDetail: () {
        final handler = widget.onOpenDetail;
        if (handler != null) {
          handler(post);
        } else {
          _openDetail(post);
        }
      },
      onOpenProfile: widget.showAuthor ? () => _openProfile(post.userId) : null,
      onToggleLike: widget.showActions ? () => _toggleLike(post) : null,
      onOpenImage: (urls, index) => _openImage(urls, index),
      onOpenVideo: _openVideo,
      onEdit: widget.onEdit == null ? null : () => widget.onEdit!(post),
      onDelete: widget.onDelete == null ? null : () => widget.onDelete!(post),
    );
  }

  void _openImage(List<String> urls, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageGalleryPage(imageUrls: urls, initialIndex: index),
      ),
    );
  }

  void _openVideo(MediaModel media) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerPage(url: media.url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shrinkWrap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final post in widget.posts) _buildCard(post),
          if (widget.footer != null) widget.footer!,
        ],
      );
    }

    final footerCount = widget.footer == null ? 0 : 1;
    return ListView.builder(
      controller: widget.controller,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: widget.posts.length + footerCount,
      itemBuilder: (context, index) {
        if (index >= widget.posts.length) return widget.footer!;
        return _buildCard(widget.posts[index]);
      },
    );
  }
}

/// 列表底部的加载更多指示。
class PostListFooter extends StatelessWidget {
  const PostListFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
