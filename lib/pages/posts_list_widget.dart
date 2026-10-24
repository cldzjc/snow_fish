import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/entity_service.dart';
import '../services/comment_service.dart';
import '../models/base_entity.dart';
import '../utils/time_utils.dart';
import 'post_detail_page.dart';
import 'profile_page.dart';

class PostsListWidget extends StatefulWidget {
  const PostsListWidget({super.key});

  @override
  State<PostsListWidget> createState() => _PostsListWidgetState();
}

class _PostsListWidgetState extends State<PostsListWidget> {
  late Future<List<BaseEntity>> _future;
  final EntityService _entityService = EntityService();
  final CommentService _commentService = CommentService();

  void _openPostDetail(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailPage(postId: postId)),
    );
  }

  @override
  void initState() {
    super.initState();
    _future = _entityService.fetchEntities(type: 'post');
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

  // 获取帖子统计数据
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

  // 切换点赞状态
  Future<void> _toggleLike(String postId) async {
    try {
      await _entityService.toggleVote(entityId: postId, score: 5);
      setState(() {
        _future = _entityService.fetchEntities(type: 'post');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openPostDetail(post.id),
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
                              InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfilePage(userId: post.userId),
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundImage: NetworkImage(authorAvatar),
                                ),
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
                                // 用户名 + 时间
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ProfilePage(
                                                  userId: post.userId,
                                                ),
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
                                // 媒体（支持多图左右滑动）
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
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount: media.length,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(width: 8),
                                                  itemBuilder: (context, index) {
                                                    return ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: SizedBox(
                                                        width: imageWidth,
                                                        child: CachedNetworkImage(
                                                          imageUrl:
                                                              media[index].url,
                                                          fit: BoxFit.cover,
                                                          placeholder: (c, u) =>
                                                              Container(
                                                                color: Colors
                                                                    .grey[200],
                                                              ),
                                                          errorWidget:
                                                              (
                                                                c,
                                                                u,
                                                                e,
                                                              ) => const Icon(
                                                                Icons
                                                                    .broken_image,
                                                              ),
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
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black54,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '${media.length} 图',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                // 操作栏：爱心、评论（真实数据）
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
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
                                              onTap: () =>
                                                  _openPostDetail(post.id),
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
              },
            );
          },
        );
      },
    );
  }
}
