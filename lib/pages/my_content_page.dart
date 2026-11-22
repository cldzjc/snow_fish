import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/comment_service.dart';
import '../services/entity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/app/app_tabs.dart';
import '../widgets/app/status_chip.dart';
import 'post_detail_page.dart';

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
    MyContentKind.about => '关于 Snow Fish',
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
        case MyContentKind.community:
        case MyContentKind.about:
        case MyContentKind.settings:
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
      return _staticScaffold('社区服务', '举报、申诉与社区规则说明会放在这里，目前还在整理。');
    }
    if (widget.kind == MyContentKind.about) {
      return _staticScaffold(
        '关于 Snow Fish',
        'Snow Fish（skneo）是给滑雪人的日常社区：\n记录雪上日常，也找到下一趟的同伴。',
      );
    }
    if (widget.kind == MyContentKind.settings) {
      return _staticScaffold('设置', '账号与通知设置尚未开放。如需修改资料，请在「我的」页进入「编辑资料」。');
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
          return _EntityRow(
            entity: item,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailPage(postId: item.id),
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

class _EntityRow extends StatelessWidget {
  const _EntityRow({required this.entity, required this.onTap});

  final BaseEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isActivity = entity.entityType.startsWith('activity_');
    final region = entity.extraData['region_id']?.toString().trim() ?? '';
    final excerpt = (entity.content ?? '').trim();

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    entity.title,
                    style: AppText.title.copyWith(color: colors.ink),
                  ),
                ),
                if (isActivity)
                  ActivityStatusChip(
                    status:
                        entity.extraData['activity_status']?.toString() ??
                        'recruiting',
                  ),
              ],
            ),
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall.copyWith(color: colors.muted),
              ),
            ],
            if (region.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                region,
                style: AppText.caption.copyWith(color: colors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
