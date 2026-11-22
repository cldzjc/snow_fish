import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/entity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/app/media_strip.dart';
import '../widgets/app/region_tag.dart';
import 'image_gallery_page.dart';
import 'post_detail_page.dart';
import 'profile_page.dart';
import 'video_player_page.dart';

/// 发布或删除后触发列表刷新（+1）。
final ValueNotifier<int> feedRefreshTick = ValueNotifier<int>(0);

class PostsListWidget extends StatefulWidget {
  const PostsListWidget({super.key});

  @override
  State<PostsListWidget> createState() => _PostsListWidgetState();
}

class _PostsListWidgetState extends State<PostsListWidget>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 20;

  final EntityService _entityService = EntityService();
  final Map<String, Map<String, dynamic>> _profileCache = {};
  final Map<String, int> _likeCounts = {};
  final Set<String> _likedIds = {};
  final Set<String> _likeInFlight = {};
  final ScrollController _scrollController = ScrollController();

  final List<BaseEntity> _posts = <BaseEntity>[];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _profilesLoading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    feedRefreshTick.addListener(_onExternalRefresh);
    _loadInitial();
  }

  @override
  void dispose() {
    feedRefreshTick.removeListener(_onExternalRefresh);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) _refresh();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final posts = await _entityService.fetchSkCommunity(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _hasMore = posts.length >= _pageSize;
        _initialLoading = false;
      });
      _loadProfiles(posts);
      _loadLikeStats(posts);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _profileCache.clear();
    _likeCounts.clear();
    _likedIds.clear();
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _entityService.fetchSkCommunity(
        limit: _pageSize,
        offset: _posts.length,
      );
      if (!mounted) return;
      final existing = _posts.map((item) => item.id).toSet();
      final fresh = more.where((item) => !existing.contains(item.id)).toList();
      setState(() {
        _posts.addAll(fresh);
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
      if (fresh.isNotEmpty) {
        _loadProfiles(fresh);
        _loadLikeStats(fresh);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadProfiles(List<BaseEntity> posts) async {
    final userIds = posts.map((post) => post.userId).toSet().toList();
    final missingIds = userIds
        .where((userId) => !_profileCache.containsKey(userId))
        .toList();
    if (missingIds.isEmpty || !mounted) return;

    setState(() => _profilesLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .inFilter('id', missingIds);
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

  void _openDetail(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: postId)),
    );
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_initialLoading) {
      return const AppLoadingSkeleton();
    }

    if (_error != null && _posts.isEmpty) {
      final message = _error!;
      final text = message.contains('network:')
          ? '网络连接失败，请检查网络'
          : message.contains('permission:')
          ? '权限不足，无法加载内容'
          : '暂时没有加载出来';
      return AppStateView(
        icon: AppIcons.alert,
        title: text,
        description: '请检查网络后再试一次。',
        actionLabel: '重新加载',
        onAction: _loadInitial,
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppStateView(
          icon: AppIcons.mountain,
          title: '还没有动态',
          description: '留一点空白，等下一段雪上的故事。',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
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
          return _PostRow(
            post: _posts[index],
            profile: _profileCache[_posts[index].userId],
            profileLoading: _profilesLoading,
            likeCount: _likeCounts[_posts[index].id] ?? 0,
            liked: _likedIds.contains(_posts[index].id),
            onOpenDetail: () => _openDetail(_posts[index].id),
            onOpenProfile: () => _openProfile(_posts[index].userId),
            onToggleLike: () => _toggleLike(_posts[index]),
            onOpenImage: (urls, i) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ImageGalleryPage(imageUrls: urls, initialIndex: i),
              ),
            ),
            onOpenVideo: (media) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerPage(url: media.url),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({
    required this.post,
    required this.profile,
    required this.profileLoading,
    required this.likeCount,
    required this.liked,
    required this.onOpenDetail,
    required this.onOpenProfile,
    required this.onToggleLike,
    required this.onOpenImage,
    required this.onOpenVideo,
  });

  final BaseEntity post;
  final Map<String, dynamic>? profile;
  final bool profileLoading;
  final int likeCount;
  final bool liked;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenProfile;
  final VoidCallback onToggleLike;
  final void Function(List<String> urls, int index) onOpenImage;
  final void Function(dynamic media) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final nickname = (profile?['nickname'] as String?)?.trim();
    final avatarUrl = profile?['avatar_url'] as String?;
    final displayName = (nickname == null || nickname.isEmpty)
        ? (profileLoading ? '加载资料…' : '雪友')
        : nickname;
    final content = post.content ?? '';
    final excerpt = content.length > 150
        ? '${content.substring(0, 150)}…'
        : content;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: '查看作者主页',
                child: GestureDetector(
                  onTap: onOpenProfile,
                  child: AppAvatar(url: avatarUrl),
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
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title.copyWith(color: colors.ink),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Text(
                            TimeUtils.formatRelativeTime(post.createdAt),
                            style: AppText.meta.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: AppSpace.xs),
                        RegionTag(
                          region: profile!['resident_region'] as String?,
                          resort: profile!['resident_resort'] as String?,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenDetail,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: AppText.title.copyWith(color: colors.ink),
                      ),
                      if (excerpt.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          excerpt,
                          style: AppText.body.copyWith(color: colors.ink),
                        ),
                      ],
                    ],
                  ),
                ),
                if (post.media.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  MediaStrip(
                    media: post.media,
                    onOpenImage: onOpenImage,
                    onOpenVideo: (media) => onOpenVideo(media),
                  ),
                ],
                const SizedBox(height: AppSpace.xs),
                Row(
                  children: [
                    _Action(
                      icon: liked ? AppIcons.heartFilled : AppIcons.heart,
                      label: likeCount > 0 ? '$likeCount' : '点赞',
                      active: liked,
                      onTap: onToggleLike,
                    ),
                    const SizedBox(width: AppSpace.xl),
                    _Action(
                      icon: AppIcons.comment,
                      label: post.commentCount > 0
                          ? '${post.commentCount}'
                          : '评论',
                      onTap: onOpenDetail,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
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
