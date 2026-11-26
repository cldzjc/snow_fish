import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../models/refresh_result.dart';
import '../services/entity_service.dart';
import '../services/my_profile_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/post_card.dart';
import 'image_gallery_page.dart';
import 'post_detail_page.dart';
import 'profile_page.dart';
import 'video_player_page.dart';

/// 发布或删除后触发列表刷新（+1）。
final ValueNotifier<int> feedRefreshTick = ValueNotifier<int>(0);

class PostsListWidget extends StatefulWidget {
  const PostsListWidget({
    super.key,
    this.topInset = 0,
    this.circleIds,
    this.emptyTitle,
    this.emptyDescription,
  });

  /// 列表顶部的留白（首页把顶栏做成浮层后，用它让首条内容落在顶栏下方）。
  /// 这段留白属于滚动内容，会和列表一起滚走，不会在顶部留下空白。
  final double topInset;

  /// 非空时只展示这些圈子下的帖子；为空时是 sk社区。
  final List<String>? circleIds;

  /// 空列表时的文案。
  final String? emptyTitle;
  final String? emptyDescription;

  @override
  State<PostsListWidget> createState() => PostsListWidgetState();
}

class PostsListWidgetState extends State<PostsListWidget>
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
    MyProfileStore.changedTick.addListener(_onProfileChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    feedRefreshTick.removeListener(_onExternalRefresh);
    MyProfileStore.changedTick.removeListener(_onProfileChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 自己的资料（昵称/地区）变了：清掉作者缓存再拉一次。
  void _onProfileChanged() {
    if (!mounted) return;
    final myId = MyProfileStore.userId;
    if (myId != null) _profileCache.remove(myId);
    reloadProfiles();
  }

  /// 重新拉一遍当前列表所有作者的资料（地区标签会跟着更新）。
  Future<void> reloadProfiles() async {
    if (!mounted) return;
    final posts = List<BaseEntity>.from(_posts);
    if (posts.isEmpty) return;
    await _loadProfiles(posts, force: true);
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

  @override
  void didUpdateWidget(covariant PostsListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_circleKey(oldWidget.circleIds) != _circleKey(widget.circleIds)) {
      _loadInitial();
    }
  }

  static String _circleKey(List<String>? ids) =>
      (ids ?? const <String>[]).join('|');

  bool get _isCircleFeed => (widget.circleIds ?? const <String>[]).isNotEmpty;

  Future<List<BaseEntity>> _fetchPage(int offset) {
    if (_isCircleFeed) {
      return _entityService.fetchCirclePosts(
        circleIds: widget.circleIds!,
        limit: _pageSize,
        offset: offset,
      );
    }
    return _entityService.fetchSkCommunity(limit: _pageSize, offset: offset);
  }

  Future<void> _loadInitial({
    bool showSkeleton = true,
    bool forceProfiles = false,
  }) async {
    if (showSkeleton) {
      setState(() {
        _initialLoading = true;
        _error = null;
      });
    } else {
      // 下拉刷新时保留现有内容，避免列表闪成骨架屏。
      setState(() => _error = null);
    }
    try {
      final posts = await _fetchPage(0);
      if (!mounted) return;
      final known = _posts.map((item) => item.id).toSet();
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _hasMore = posts.length >= _pageSize;
        _initialLoading = false;
      });
      _lastNewCount = known.isEmpty
          ? 0
          : posts.where((item) => !known.contains(item.id)).length;
      _lastFailed = false;
      _loadProfiles(posts, force: forceProfiles);
      _loadLikeStats(posts);
    } catch (e) {
      if (!mounted) return;
      _lastFailed = true;
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  /// 最近一次刷新的增量与失败状态，供 [refreshNow] 返回。
  int _lastNewCount = 0;
  bool _lastFailed = false;

  Future<void> _refresh() =>
      _loadInitial(showSkeleton: false, forceProfiles: true);

  /// 下拉刷新：返回相比刷新前「新增」的条数。
  Future<RefreshResult> refreshNow() async {
    await _loadInitial(showSkeleton: false, forceProfiles: true);
    if (_lastFailed) return RefreshResult.failure;
    return RefreshResult(newCount: _lastNewCount, total: _posts.length);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchPage(_posts.length);
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

  Future<void> _loadProfiles(
    List<BaseEntity> posts, {
    bool force = false,
  }) async {
    final userIds = posts.map((post) => post.userId).toSet().toList();
    final missingIds = force
        ? userIds
        : userIds
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
      return AppStateView(
        icon: AppIcons.mountain,
        title: widget.emptyTitle ?? '还没有动态',
        description: widget.emptyDescription ?? '留一点空白，等下一段雪上的故事。',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: widget.topInset, bottom: 92),
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
        return PostCard(
          post: _posts[index],
          authorName: (() {
            final nickname =
                (_profileCache[_posts[index].userId]?['nickname'] as String?)
                    ?.trim();
            if (nickname == null || nickname.isEmpty) {
              return _profilesLoading ? '加载资料…' : '雪友';
            }
            return nickname;
          })(),
          authorAvatar:
              _profileCache[_posts[index].userId]?['avatar_url'] as String?,
          region:
              _profileCache[_posts[index].userId]?['resident_region']
                  as String?,
          resort:
              _profileCache[_posts[index].userId]?['resident_resort']
                  as String?,
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
            MaterialPageRoute(builder: (_) => VideoPlayerPage(url: media.url)),
          ),
        );
      },
    );
  }
}
