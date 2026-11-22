import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/entity_service.dart';
import 'post_detail_page.dart';
import 'publish_post_page.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final EntityService _entityService = EntityService();
  late Future<List<BaseEntity>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BaseEntity>> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];
    return _entityService.fetchUserEntities(userId: uid, type: 'post');
  }

  Future<void> _delete(BaseEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('确认删除该帖子吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
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
      setState(() => _future = _load());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('帖子已删除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的帖子')),
      body: FutureBuilder<List<BaseEntity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('加载失败，请稍后重试'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('你还没有发布帖子'));
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = data[index];
                return Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      item.content == null || item.content!.isEmpty
                          ? '无正文'
                          : item.content!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '编辑',
                          onPressed: () async {
                            final saved = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PublishPostPage(initialPost: item),
                              ),
                            );
                            if (saved == true && mounted) {
                              setState(() => _future = _load());
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '删除',
                          onPressed: () => _delete(item),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(postId: item.id),
                        ),
                      );
                      if (changed == true && mounted) {
                        setState(() => _future = _load());
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
