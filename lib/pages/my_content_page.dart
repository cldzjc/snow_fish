import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/comment_service.dart';
import '../services/entity_service.dart';
import '../utils/time_utils.dart';
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
  final MyContentKind kind;

  const MyContentPage({super.key, required this.kind});

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

class _MyContentPageState extends State<MyContentPage>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  final _entityService = EntityService();
  final _commentService = CommentService();

  TabController? _activityTabs;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _comments = [];
  List<BaseEntity> _favorites = [];
  List<BaseEntity> _created = [];
  List<BaseEntity> _joined = [];
  List<BaseEntity> _ended = [];

  @override
  void initState() {
    super.initState();
    if (widget.kind == MyContentKind.activities) {
      _activityTabs = TabController(length: 3, vsync: this);
    }
    _load();
  }

  @override
  void dispose() {
    _activityTabs?.dispose();
    super.dispose();
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
          final merged = <String, BaseEntity>{};
          for (final item in [...created, ...joined]) {
            merged[item.id] = item;
          }
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
    if (user == null) return [];
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
    if (ids.isEmpty) return [];
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
      return _staticScaffold('社区服务功能正在整理');
    }
    if (widget.kind == MyContentKind.about) {
      return _staticScaffold('Snow Fish — skneo 滑雪社区');
    }
    if (widget.kind == MyContentKind.settings) {
      return _staticScaffold('设置功能尚未开放');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: _activityTabs == null
            ? null
            : TabBar(
                controller: _activityTabs,
                tabs: const [
                  Tab(text: '我发起的'),
                  Tab(text: '我参与的'),
                  Tab(text: '已结束'),
                ],
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _staticScaffold(String text) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(child: Text(text)),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载失败，请稍后重试'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }

    if (widget.kind == MyContentKind.comments) {
      return _buildCommentList();
    }
    if (widget.kind == MyContentKind.favorites) {
      return _buildEntityList(_favorites, '还没有收藏内容');
    }
    return TabBarView(
      controller: _activityTabs,
      children: [
        _buildEntityList(_created, '还没有发起活动'),
        _buildEntityList(_joined, '还没有参与活动'),
        _buildEntityList(_ended, '没有已结束的活动'),
      ],
    );
  }

  Widget _buildCommentList() {
    if (_comments.isEmpty) {
      return _emptyState('还没有发表评论');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final item = _comments[index];
          final createdAt = DateTime.tryParse(
            item['created_at']?.toString() ?? '',
          );
          return ListTile(
            title: Text(
              item['content']?.toString() ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              createdAt == null ? '' : TimeUtils.formatRelativeTime(createdAt),
            ),
            trailing: const Icon(Icons.chevron_right),
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

  Widget _buildEntityList(List<BaseEntity> items, String emptyText) {
    if (items.isEmpty) return _emptyState(emptyText);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          final isActivity = item.entityType.startsWith('activity_');
          final subtitleParts = <String>[
            if (isActivity) item.extraData['region_id']?.toString() ?? '未设置地区',
            if (item.content != null && item.content!.trim().isNotEmpty)
              item.content!.trim(),
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.title),
              subtitle: subtitleParts.isEmpty
                  ? null
                  : Text(
                      subtitleParts.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailPage(postId: item.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(String text) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(text)),
        ],
      ),
    );
  }
}
