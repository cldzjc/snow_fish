import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/base_entity.dart';
import '../models/comment_model.dart';
import '../services/entity_service.dart';
import '../services/comment_service.dart';
import '../services/moderation_service.dart';
import '../widgets/post_action_bar.dart';
import '../widgets/comment_item.dart';
import '../widgets/comment_input_sheet.dart';
import '../utils/time_utils.dart';
import 'image_gallery_page.dart';
import 'profile_page.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final EntityService _entityService;
  late final CommentService _commentService;
  final _moderationService = ModerationService();
  BaseEntity? _post;
  List<CommentModel> _comments = [];
  Map<String, dynamic>? _userProfile;
  bool _isLoadingPost = true;
  bool _isLoadingComments = true;

  @override
  void initState() {
    super.initState();
    _entityService = EntityService();
    _commentService = CommentService();
    _loadPost();
    _loadComments();
  }

  Future<void> _loadPost() async {
    try {
      final post = await _entityService.fetchEntity(widget.postId);
      if (post != null) {
        final userProfile = await _getUserProfile(post.userId);
        if (mounted) {
          setState(() {
            _post = post;
            _userProfile = userProfile;
            _isLoadingPost = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 加载帖子失败: $e');
      if (mounted) {
        setState(() => _isLoadingPost = false);
      }
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getCommentTree(
        entityId: widget.postId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 加载评论失败: $e');
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  Future<void> _reportPost() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('举报帖子'),
        children: ['广告引流', '色情或暴力', '辱骂骚扰', '虚假内容', '其他']
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Text(item),
              ),
            )
            .toList(),
      ),
    );
    if (reason == null) return;
    await _submitReport('entity', widget.postId, reason);
  }

  Future<void> _reportComment(String commentId) async {
    await _submitReport('comment', commentId, '其他');
  }

  Future<void> _submitReport(
    String targetType,
    String targetId,
    String reason,
  ) async {
    try {
      await _moderationService.report(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('举报已提交')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('举报失败：$e')));
      }
    }
  }

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

  void _showCommentInputSheet({CommentModel? replyTo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentInputSheet(
        entityId: widget.postId,
        replyTo: replyTo,
        onCommentSubmitted: (newComment) {
          // 添加新评论到列表
          if (replyTo == null) {
            // 发布的是顶级评论
            setState(() {
              _comments.insert(0, newComment);
            });
          } else {
            // 发布的是回复，刷新评论树
            _loadComments();
          }
        },
      ),
    );
  }

  void _openMediaGallery(List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ImageGalleryPage(imageUrls: urls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子详情'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reportPost,
            tooltip: '举报',
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: _isLoadingPost
          ? Center(child: CircularProgressIndicator())
          : _post == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('帖子不存在或已被删除'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('返回'),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // 帖子内容
                SliverToBoxAdapter(child: _buildPostContent()),

                // 操作栏
                SliverToBoxAdapter(
                  child: PostActionBar(
                    postId: widget.postId,
                    userId: Supabase.instance.client.auth.currentUser?.id ?? '',
                  ),
                ),

                // 评论标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '评论 (${_comments.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // 评论列表
                _isLoadingComments
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    : _comments.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('暂无评论'),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final comment = _comments[index];
                          return CommentItem(
                            comment: comment,
                            onReplyPressed: () {
                              _showCommentInputSheet(replyTo: comment);
                            },
                            onDeleted: (deletedComment) {
                              _loadComments();
                            },
                            onLikeChanged: () {
                              // 可选：更新点赞计数
                            },
                            onAuthorTap: _openUserProfile,
                            onReportPressed: () => _reportComment(comment.id),
                          );
                        }, childCount: _comments.length),
                      ),

                // 底部间距
                SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCommentInputSheet();
        },
        child: Icon(Icons.comment),
        tooltip: '写评论',
      ),
    );
  }

  void _openUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  Widget _buildPostContent() {
    final post = _post!;
    final media = post.media;
    final authorName = (_userProfile?['nickname'] as String?) ?? '匿名用户';
    final authorAvatar =
        (_userProfile?['avatar_url'] as String?) ??
        'https://api.dicebear.com/7.x/avataaars/svg?seed=${post.userId}';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者信息
          Row(
            children: [
              InkWell(
                onTap: () => _openUserProfile(post.userId),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(authorAvatar),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openUserProfile(post.userId),
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
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 标题
          Text(
            post.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              height: 1.4,
            ),
          ),
          SizedBox(height: 12),

          // 内容
          Text(
            post.content ?? '',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),

          // 媒体
          if (media.isNotEmpty)
            SizedBox(
              height: 300,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: media.length,
                itemBuilder: (context, index) {
                  final m = media[index];
                  final imageUrls = media.map((e) => e.url).toList();
                  return Container(
                    margin: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _openMediaGallery(imageUrls, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: m.url,
                          fit: BoxFit.cover,
                          width: 300,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
