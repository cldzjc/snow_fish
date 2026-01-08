import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../post_service.dart';

class PostsListWidget extends StatefulWidget {
  const PostsListWidget({super.key});

  @override
  State<PostsListWidget> createState() => _PostsListWidgetState();
}

class _PostsListWidgetState extends State<PostsListWidget> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = PostService().getPosts();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final msg = snap.error?.toString() ?? '';
          String display = '加载失败，请稍后重试';
          if (msg.contains('network:')) display = '网络连接失败，请检查网络';
          if (msg.contains('permission:')) display = '权限错误：无法加载帖子';
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(display),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () =>
                      setState(() => _future = PostService().getPosts()),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return const Center(child: Text('暂无帖子'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final p = posts[i];
            final media = (p['media_urls'] as List?)?.cast<String>() ?? [];
            final firstMedia = media.isNotEmpty ? media.first : null;
            final content = (p['content'] as String?) ?? '';
            final title = (p['title'] as String?) ?? '';
            // 优先显示 author_name，如果不存在则显示 user_id 的截断版本
            final authorName =
                (p['author_name'] as String?) ??
                (p['author_nickname'] as String?) ??
                (p['user_id']?.toString().substring(0, 8)) ??
                '匿名';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (firstMedia != null)
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: firstMedia,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (c, u, e) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    if (firstMedia != null) const SizedBox(height: 8),
                    Text(
                      content.length > 120
                          ? '${content.substring(0, 120)}...'
                          : content,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '发布人: $authorName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
