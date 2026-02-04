import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/base_entity.dart';
import '../models/comment_model.dart';
import '../services/entity_service.dart';
import '../services/comment_service.dart';
import '../widgets/post_action_bar.dart';
import '../widgets/comment_item.dart';
import '../widgets/comment_input_sheet.dart';
import '../utils/time_utils.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final EntityService _entityService;
  late final CommentService _commentService;
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
      print('❌ 加载帖子失败: $e');
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
      print('❌ 加载评论失败: $e');
      if (mounted) {
        setState(() => _isLoadingComments = false);
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
    setState(() => _replyingTo = replyTo);
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
          setState(() => _replyingTo = null);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('帖子详情'), elevation: 0),
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
                    onCommentPressed: () {
                      _showCommentInputSheet();
                    },
                    onSharePressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('分享功能开发中...')));
                    },
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
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(authorAvatar),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
                  return Container(
                    margin: EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: m.url,
                        fit: BoxFit.cover,
                        width: 300,
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
