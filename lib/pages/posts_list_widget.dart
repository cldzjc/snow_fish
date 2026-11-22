import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/entity_service.dart';
import '../services/comment_service.dart';
import '../models/base_entity.dart';
import '../models/media_model.dart';
import '../utils/time_utils.dart';
import 'post_detail_page.dart';
import 'profile_page.dart';

/// 发布成功后通知首页刷新（+1 触发）。
final ValueNotifier<int> feedRefreshTick = ValueNotifier<int>(0);

class PostsListWidget extends StatefulWidget {
  const PostsListWidget({super.key});

  @override
  State<PostsListWidget> createState() => _PostsListWidgetState();
}

class _PostsListWidgetState extends State<PostsListWidget> {
  static const int _pageSize = 20;

  final EntityService _entityService = EntityService();
  final CommentService _commentService = CommentService();
  final Map<String, Map<String, dynamic>> _profileCache = {};
  final ScrollController _scrollController = ScrollController();
  final Set<String> _likeInFlight = {};

  final List<BaseEntity> _posts = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _profilesLoading = false;
  String? _error;

  void _openPostDetail(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailPage(postId: postId)),
    );
  }

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
    if (!mounted) return;
    _refresh();
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
      _loadProfiles(_posts);
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
      setState(() {
        final existing = _posts.map((item) => item.id).toSet();
        _posts.addAll(more.where((item) => !existing.contains(item.id)));
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
      _loadProfiles(_posts);
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

  Map<String, dynamic>? _profileFor(String userId) => _profileCache[userId];

  Future<Map<String, int>> _getPostStats(String postId) async {
    try {
      final stats = await _entityService.getVoteStats(postId);
      final commentCount = await _commentService.getCommentCount(
        entityId: postId,
      );
      return {
        'like_count': stats['like_count'] ?? 0,
        'comment_count': commentCount,
      };
    } catch (e) {
      return {'like_count': 0, 'comment_count': 0};
    }
  }

  Future<void> _toggleLike(String postId) async {
    if (_likeInFlight.contains(postId)) return;
    _likeInFlight.add(postId);
    try {
      await _entityService.toggleVote(entityId: postId, score: 5);
      if (!mounted) return;
      await _loadInitial();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    } finally {
      _likeInFlight.remove(postId);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required IconData activeIcon,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 18,
              color: isActive ? Colors.red[400] : Colors.grey[600],
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _posts.isEmpty) {
      final msg = _error!;
      String display = '加载失败，请稍后重试';
      if (msg.contains('network:')) display = '网络连接失败，请检查网络';
      if (msg.contains('permission:')) display = '权限错误：无法加载帖子';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(display),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadInitial, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暂无帖子')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _buildPostCard(_posts[i]);
        },
      ),
    );
  }

  Widget _buildPostCard(BaseEntity post) {
    final media = post.media;
    final content = post.content ?? '';
    final title = post.title;

    final userProfile = _profileFor(post.userId);
    final authorName = userProfile == null
        ? (_profilesLoading ? '加载作者资料…' : '用户')
        : ((userProfile['nickname'] as String?)?.trim().isNotEmpty == true
              ? userProfile['nickname'] as String
              : '用户');
    final authorAvatar = userProfile?['avatar_url'] as String?;
    final residentRegion =
        (userProfile?['resident_region'] as String?)?.trim() ?? '';
    final residentResort =
        (userProfile?['resident_resort'] as String?)?.trim() ?? '';
    final locationLabel = [
      if (residentRegion.isNotEmpty) residentRegion,
      if (residentResort.isNotEmpty && residentResort != '暂无固定雪场')
        residentResort,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPostDetail(post.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: post.userId),
                      ),
                    ),
                    child: _buildAvatar(authorAvatar, post.userId),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfilePage(userId: post.userId),
                                  ),
                                ),
                                child: Text(
                                  authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                TimeUtils.formatRelativeTime(post.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              if (locationLabel.isNotEmpty)
                                Text(
                                  locationLabel,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content.length > 150
                          ? '${content.substring(0, 150)}...'
                          : content,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (media.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isMulti = media.length > 1;
                            final imageWidth = isMulti
                                ? constraints.maxWidth * 0.88
                                : constraints.maxWidth;

                            return ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 260,
                                minHeight: 120,
                              ),
                              child: SizedBox(
                                height: 220,
                                child: Stack(
                                  children: [
                                    ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: media.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: SizedBox(
                                            width: imageWidth,
                                            child: _buildMediaPreview(
                                              media[index],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (isMulti)
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '${media.length} 图',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, int>>(
                      future: _getPostStats(post.id),
                      builder: (context, statsSnap) {
                        final stats =
                            statsSnap.data ??
                            {'like_count': 0, 'comment_count': 0};
                        return FutureBuilder<bool>(
                          future: _entityService.hasVoted(
                            entityId: post.id,
                            score: 5,
                          ),
                          builder: (context, likedSnap) {
                            final isLiked = likedSnap.data ?? false;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.favorite_border,
                                  activeIcon: Icons.favorite,
                                  count: stats['like_count']!,
                                  isActive: isLiked,
                                  onTap: () => _toggleLike(post.id),
                                ),
                                const SizedBox(width: 32),
                                _buildActionButton(
                                  icon: Icons.comment_outlined,
                                  activeIcon: Icons.comment,
                                  count: stats['comment_count']!,
                                  isActive: false,
                                  onTap: () => _openPostDetail(post.id),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(MediaModel media) {
    final isVideo = media.mediaType == 'video';
    final previewUrl = isVideo
        ? (media.thumbnailUrl?.isNotEmpty == true ? media.thumbnailUrl! : null)
        : media.url;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (previewUrl == null)
          Container(
            color: Colors.grey[200],
            child: const Icon(Icons.videocam_outlined, color: Colors.grey),
          )
        else
          CachedNetworkImage(
            imageUrl: previewUrl,
            fit: BoxFit.cover,
            placeholder: (c, u) => Container(color: Colors.grey[200]),
            errorWidget: (c, u, e) => const Icon(Icons.broken_image),
          ),
        if (isVideo)
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(String? avatarUrl, String userId) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: 22,
        child: _profilesLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_outline),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundImage: CachedNetworkImageProvider(avatarUrl),
      onBackgroundImageError: (_, __) {},
    );
  }
}
