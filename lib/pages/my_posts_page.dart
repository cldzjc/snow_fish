import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/entity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import 'post_detail_page.dart';
import 'publish_post_page.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final EntityService _entityService = EntityService();

  bool _loading = true;
  String? _error;
  List<BaseEntity> _items = <BaseEntity>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _items = <BaseEntity>[];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _entityService.fetchUserEntities(
        userId: uid,
        type: 'post',
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(BaseEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('删除后不可恢复，评论与媒体会一并移除。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _entityService.deleteEntity(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('帖子已删除')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Future<void> _openDetail(BaseEntity item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: item.id)),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _edit(BaseEntity item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublishPostPage(initialPost: item)),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的帖子')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingSkeleton();
    if (_error != null) return AppStateView.error(onRetry: _load);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: const AppStateView(
          icon: AppIcons.edit,
          title: '还没有发布帖子',
          description: '从首页的发布入口记录第一段雪上日常。',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _MyPostRow(
            post: item,
            onOpen: () => _openDetail(item),
            onEdit: () => _edit(item),
            onDelete: () => _delete(item),
          );
        },
      ),
    );
  }
}

class _MyPostRow extends StatelessWidget {
  const _MyPostRow({
    required this.post,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final BaseEntity post;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final excerpt = (post.content ?? '').trim();
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySmall.copyWith(color: colors.muted),
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    TimeUtils.formatRelativeTime(post.createdAt),
                    style: AppText.caption.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              TextButton(onPressed: onEdit, child: const Text('编辑')),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
