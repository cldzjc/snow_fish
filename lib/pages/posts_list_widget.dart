import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/entity_service.dart';
import '../models/base_entity.dart';
import '../widgets/post_action_bar.dart';
import '../utils/time_utils.dart';

class PostsListWidget extends StatefulWidget {
  const PostsListWidget({super.key});

  @override
  State<PostsListWidget> createState() => _PostsListWidgetState();
}

class _PostsListWidgetState extends State<PostsListWidget> {
  late Future<List<BaseEntity>> _future;

  @override
  void initState() {
    super.initState();
    _future = EntityService().fetchEntities(type: 'post');
  }

  // 根据用户ID获取用户资料
  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return profile ?? {};
    } catch (e) {
      return {};
    }
  }

  // 构建操作按钮
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
    return FutureBuilder<List<BaseEntity>>(
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
                  onPressed: () => setState(
                    () => _future = EntityService().fetchEntities(type: 'post'),
                  ),
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
            final post = posts[i];
            final media = post.media;
            final firstMediaUrl = media.isNotEmpty ? media.first.url : null;
            final content = post.content ?? '';
            final title = post.title;

            // 异步获取用户资料并显示
            return FutureBuilder<Map<String, dynamic>>(
              future: _getUserProfile(post.userId),
              builder: (context, userSnap) {
                final userProfile = userSnap.data ?? {};
                final authorName =
                    (userProfile['nickname'] as String?) ?? '匿名用户';
                final authorAvatar =
                    (userProfile['avatar_url'] as String?) ??
                    'https://api.dicebear.com/7.x/avataaars/svg?seed=${post.userId}';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧：头像 + 竖线
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage: NetworkImage(authorAvatar),
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
                        // 右侧：用户名、时间、菜单和内容
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 用户名 + 时间 + 菜单
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          TimeUtils.formatRelativeTime(
                                            post.createdAt,
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('菜单功能开发中...'),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.more_horiz,
                                        size: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 标题
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 内容
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
                              // 媒体
                              if (firstMediaUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    height: 160,
                                    width: double.infinity,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: firstMediaUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (c, u) =>
                                            Container(color: Colors.grey[200]),
                                        errorWidget: (c, u, e) =>
                                            const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              // 操作栏：爱心、评论、转发、分享
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildActionButton(
                                    icon: Icons.favorite_border,
                                    activeIcon: Icons.favorite,
                                    count: 21,
                                    isActive: false,
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(content: Text('点赞成功')),
                                      );
                                    },
                                  ),
                                  _buildActionButton(
                                    icon: Icons.comment_outlined,
                                    activeIcon: Icons.comment,
                                    count: 10,
                                    isActive: false,
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('评论功能开发中...'),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildActionButton(
                                    icon: Icons.repeat_outlined,
                                    activeIcon: Icons.repeat,
                                    count: 0,
                                    isActive: false,
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('转发功能开发中...'),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildActionButton(
                                    icon: Icons.share_outlined,
                                    activeIcon: Icons.share,
                                    count: 12,
                                    isActive: false,
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('分享功能开发中...'),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
