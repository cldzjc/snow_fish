import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/comment_service.dart';
import '../services/contact_service.dart';
import '../services/entity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import '../widgets/app/activity_form_sheets.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/app/app_tabs.dart';
import '../widgets/post_card.dart';
import 'image_gallery_page.dart';
import 'post_detail_page.dart';
import 'video_player_page.dart';
import '../utils/error_text.dart';

enum MyContentKind {
  comments,
  favorites,
  activities,
  community,
  about,
  settings,
}

class MyContentPage extends StatefulWidget {
  const MyContentPage({super.key, required this.kind});

  final MyContentKind kind;

  String get title => switch (kind) {
    MyContentKind.comments => '我的评论',
    MyContentKind.favorites => '我的收藏',
    MyContentKind.activities => '我的活动',
    MyContentKind.community => '社区服务',
    MyContentKind.about => '关于 skneo',
    MyContentKind.settings => '设置',
  };

  @override
  State<MyContentPage> createState() => _MyContentPageState();
}

class _MyContentPageState extends State<MyContentPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final EntityService _entityService = EntityService();
  final CommentService _commentService = CommentService();

  int _activityTab = 0;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  List<BaseEntity> _favorites = <BaseEntity>[];
  List<BaseEntity> _created = <BaseEntity>[];
  List<BaseEntity> _joined = <BaseEntity>[];
  List<BaseEntity> _ended = <BaseEntity>[];
  String? _phone;

  final Map<String, Map<String, dynamic>> _profiles = {};
  final Map<String, int> _likeCounts = {};
  final Set<String> _likedIds = {};
  final Set<String> _likeInFlight = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.kind) {
        case MyContentKind.comments:
          _comments = await _commentService.getMyComments();
        case MyContentKind.favorites:
          _favorites = await _loadFavorites();
          await _loadCardContext(_favorites, withLikes: true);
        case MyContentKind.activities:
          final created = await _entityService.fetchMyCreatedActivities();
          final joined = await _entityService.fetchMyJoinedActivities();
          final merged = <String, BaseEntity>{
            for (final item in [...created, ...joined]) item.id: item,
          };
          final all = merged.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _created = created;
          _joined = joined;
          _ended = all
              .where((item) => _entityService.isActivityEnded(item))
              .toList();
          await _loadCardContext(all, withLikes: false);
        case MyContentKind.community:
        case MyContentKind.about:
        case MyContentKind.settings:
          _phone = await ContactService().loadMine();
          break;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 卡片需要的作者资料与点赞状态，按需一次性批量取回。
  Future<void> _loadCardContext(
    List<BaseEntity> entities, {
    required bool withLikes,
  }) async {
    _profiles.clear();
    _likeCounts.clear();
    _likedIds.clear();
    if (entities.isEmpty) return;
    final userIds = entities.map((item) => item.userId).toSet().toList();
    final entityIds = entities.map((item) => item.id).toList();
    try {
      final rows = await _client
          .from('user_profiles')
          .select()
          .inFilter('id', userIds);
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row);
        _profiles[map['id'] as String] = map;
      }
    } catch (_) {
      // 作者资料缺失不影响列表展示。
    }
    if (!withLikes) return;
    try {
      final counts = await _entityService.fetchLikeCounts(entityIds);
      final liked = await _entityService.fetchLikedEntityIds(entityIds);
      _likeCounts.addAll(counts);
      _likedIds.addAll(liked);
    } catch (_) {
      // 点赞状态失败时退化为 0 与未点赞。
    }
  }

  Future<void> _toggleLike(BaseEntity entity) async {
    if (_likeInFlight.contains(entity.id)) return;
    _likeInFlight.add(entity.id);
    final wasLiked = _likedIds.contains(entity.id);
    setState(() {
      if (wasLiked) {
        _likedIds.remove(entity.id);
        _likeCounts[entity.id] = (_likeCounts[entity.id] ?? 1) - 1;
      } else {
        _likedIds.add(entity.id);
        _likeCounts[entity.id] = (_likeCounts[entity.id] ?? 0) + 1;
      }
    });
    try {
      final liked = await _entityService.toggleVote(
        entityId: entity.id,
        score: 5,
      );
      if (!mounted) return;
      setState(() {
        if (liked) {
          _likedIds.add(entity.id);
        } else {
          _likedIds.remove(entity.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedIds.add(entity.id);
          _likeCounts[entity.id] = (_likeCounts[entity.id] ?? 0) + 1;
        } else {
          _likedIds.remove(entity.id);
          _likeCounts[entity.id] = (_likeCounts[entity.id] ?? 1) - 1;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '操作失败'))),
      );
    } finally {
      _likeInFlight.remove(entity.id);
    }
  }

  String _activityMetaLine(BaseEntity entity) {
    final parts = <String>[];
    final region = entity.extraData['region_id']?.toString().trim() ?? '';
    final resort = entity.extraData['resort_id']?.toString().trim() ?? '';
    final place = [region, resort].where((item) => item.isNotEmpty).join(' · ');
    if (place.isNotEmpty) parts.add(place);
    final start = DateTime.tryParse(
      entity.extraData['start_at']?.toString() ?? '',
    );
    if (start != null) {
      final local = start.toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      parts.add(
        '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}',
      );
    }
    final max = entity.extraData['max_participants'];
    if (max != null) parts.add('限 $max 人');
    return parts.join(' · ');
  }

  Future<void> _openDetail(BaseEntity entity) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: entity.id)),
    );
    if (changed == true && mounted) await _load();
  }

  Future<List<BaseEntity>> _loadFavorites() async {
    final user = _client.auth.currentUser;
    if (user == null) return <BaseEntity>[];
    final rows = await _client
        .from('interactions')
        .select('entity_id')
        .eq('user_id', user.id)
        .eq('target_type', 'entity')
        .eq('interaction_type', 'favorite');
    final ids = (rows as List)
        .map((row) => row['entity_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return <BaseEntity>[];
    final entities = await _client
        .from('entities')
        .select('*, media(*)')
        .inFilter('id', ids)
        .eq('moderation_status', 'visible')
        .order('created_at', ascending: false);
    return (entities as List)
        .map((row) => BaseEntity.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == MyContentKind.community) {
      // 没有实质内容就明说，别写成「还在整理」，用户会以为项目没做完。
      return _staticScaffold(
        '社区服务',
        '举报与申诉入口：在任意帖子或评论右上角选择「举报」即可。\n管理员处理后会通过通知告知结果。',
      );
    }
    if (widget.kind == MyContentKind.about) {
      return _staticScaffold(
        '关于 skneo',
        'skneo · sk社区 是给滑雪人的日常社区：\n记录雪上日常，也找到下一趟的同伴。',
      );
    }
    if (widget.kind == MyContentKind.settings) {
      return _buildSettings();
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (widget.kind == MyContentKind.activities)
            AppTabs(
              tabs: const ['我发起的', '我参与的', '已结束'],
              index: _activityTab,
              onChanged: (index) => setState(() => _activityTab = index),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          InkWell(
            onTap: _editPhone,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xl,
                vertical: AppSpace.lg,
              ),
              child: Row(
                children: [
                  Text(
                    '手机号',
                    style: AppText.body.copyWith(color: colors.ink),
                  ),
                  const Spacer(),
                  Text(
                    _phone == null ? '未填写' : ContactService.mask(_phone!),
                    style: AppText.bodySmall.copyWith(color: colors.muted),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Icon(AppIcons.chevron, size: 18, color: colors.muted),
                ],
              ),
            ),
          ),
          Divider(color: colors.line, height: 1),
          if (_phone != null)
            InkWell(
              onTap: _clearPhone,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xl,
                  vertical: AppSpace.lg,
                ),
                child: Text(
                  '清除手机号',
                  style: AppText.body.copyWith(color: colors.danger),
                ),
              ),
            ),
          if (_phone != null) Divider(color: colors.line, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              0,
            ),
            child: Text(
              '手机号只在约活动时提供给对方，个人主页不会展示。',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: Text(
              '修改昵称、头像、常驻地点，请在「我的」页点「编辑资料」。',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPhone() async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    final saved = await showPhoneSheet(
      context,
      initial: _phone,
      title: _phone == null ? '填写手机号' : '修改手机号',
    );
    if (saved == null || !mounted) return;
    setState(() => _phone = saved);
  }

  Future<void> _clearPhone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除手机号？'),
        content: const Text('清除后，发起活动时会要求你重新填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ContactService().clearMine();
    if (!mounted) return;
    setState(() => _phone = null);
  }

  Widget _staticScaffold(String title, String text) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: colors.muted),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingSkeleton();
    if (_error != null) return AppStateView.error(onRetry: _load);

    switch (widget.kind) {
      case MyContentKind.comments:
        return _buildComments();
      case MyContentKind.favorites:
        return _buildEntities(_favorites, '还没有收藏内容', '在帖子详情点收藏，就会出现在这里。');
      case MyContentKind.activities:
        final items = switch (_activityTab) {
          0 => _created,
          1 => _joined,
          _ => _ended,
        };
        return _buildEntities(items, '还没有活动', '发起的与报名的活动都会出现在这里。');
      case MyContentKind.community:
      case MyContentKind.about:
      case MyContentKind.settings:
        return const SizedBox.shrink();
    }
  }

  Widget _buildComments() {
    if (_comments.isEmpty) {
      return _emptyListView('还没有发表评论', '在帖子详情写下第一句。');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const SizedBox.shrink(),
        itemBuilder: (context, index) {
          final item = _comments[index];
          final createdAt = DateTime.tryParse(
            item['created_at']?.toString() ?? '',
          );
          return _CommentRow(
            content: item['content']?.toString() ?? '',
            time: createdAt == null
                ? ''
                : TimeUtils.formatRelativeTime(createdAt),
            onTap: () {
              final entityId = item['entity_id'] as String?;
              if (entityId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailPage(postId: entityId),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEntities(
    List<BaseEntity> items,
    String emptyTitle,
    String emptyText,
  ) {
    if (items.isEmpty) return _emptyListView(emptyTitle, emptyText);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final profile = _profiles[item.userId];
          final isActivity = item.entityType.startsWith('activity_');
          return PostCard(
            post: item,
            authorName: profile?['nickname'] as String?,
            authorAvatar: profile?['avatar_url'] as String?,
            region: profile?['resident_region'] as String?,
            resort: profile?['resident_resort'] as String?,
            statusText: isActivity
                ? (item.extraData['activity_status']?.toString() ??
                      'recruiting')
                : null,
            metaLine: isActivity ? _activityMetaLine(item) : null,
            likeCount: _likeCounts[item.id] ?? 0,
            liked: _likedIds.contains(item.id),
            showCommentAction: !isActivity,
            onToggleLike: widget.kind == MyContentKind.favorites
                ? () => _toggleLike(item)
                : null,
            onOpenDetail: () => _openDetail(item),
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

  Widget _emptyListView(String title, String text) {
    return RefreshIndicator(
      onRefresh: _load,
      child: AppStateView(
        icon: AppIcons.mountain,
        title: title,
        description: text,
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.content,
    required this.time,
    required this.onTap,
  });

  final String content;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: AppText.body.copyWith(color: colors.ink)),
            const SizedBox(height: AppSpace.sm),
            Text(time, style: AppText.caption.copyWith(color: colors.muted)),
          ],
        ),
      ),
    );
  }
}
