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
import 'publish_post_page.dart';
import 'video_player_page.dart';

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
  bool _commentsError = false;
  bool _joinedActivity = false;
  bool _activityBusy = false;
  int _participantCount = 0;
  bool _deleting = false;

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
        if (post.entityType.startsWith('activity_')) {
          await _loadActivityState();
        }
      }
    } catch (e) {
      debugPrint('❌ 加载帖子失败: $e');
      if (mounted) {
        setState(() => _isLoadingPost = false);
      }
    }
  }

  Future<void> _loadActivityState() async {
    try {
      final rows = await Supabase.instance.client
          .from('activity_participants')
          .select('user_id, status')
          .eq('entity_id', widget.postId);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
      var joined = false;
      var count = 0;
      for (final row in rows as List) {
        if (row['status'] != 'joined') continue;
        count++;
        if (row['user_id'] == currentUserId) joined = true;
      }
      if (!mounted) return;
      setState(() {
        _participantCount = count;
        _joinedActivity = joined;
      });
    } catch (e) {
      debugPrint('加载活动报名状态失败: $e');
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
          _commentsError = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 加载评论失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
          _commentsError = true;
        });
      }
    }
  }

  Future<void> _reportPost() async {
    final report = await _showReportDialog('举报帖子');
    if (report == null) return;
    await _submitReport('entity', widget.postId, report.$1, report.$2);
  }

  Future<void> _reportComment(String commentId) async {
    final report = await _showReportDialog('举报评论');
    if (report == null) return;
    await _submitReport('comment', commentId, report.$1, report.$2);
  }

  Future<(String, String?)?> _showReportDialog(String title) async {
    String? reason;
    final detailsController = TextEditingController();
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '举报原因'),
                items: const ['广告引流', '色情或暴力', '辱骂骚扰', '虚假内容', '其他']
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => reason = value),
              ),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '补充说明（可选）',
                  hintText: '请描述具体问题，帮助管理员判断',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (reason != null) {
                Navigator.pop(context, (
                  reason!,
                  detailsController.text.trim(),
                ));
              }
            },
            child: const Text('提交举报'),
          ),
        ],
      ),
    );
    detailsController.dispose();
    return result;
  }

  Future<void> _submitReport(
    String targetType,
    String targetId,
    String reason,
    String? details,
  ) async {
    try {
      await _moderationService.report(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        details: details,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('举报已提交')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('举报失败：${_reportErrorMessage(e)}')),
        );
      }
    }
  }

  String _reportErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('不能举报自己的内容')) return '不能举报自己的内容';
    if (text.contains('举报目标不存在')) return '该内容已不存在，无法举报';
    if (text.contains('操作过于频繁')) return '举报提交过于频繁，请稍后再试';
    if (text.contains('23505')) return '你已经提交过类似举报，请勿重复提交';
    return '暂时无法提交举报，请稍后再试';
  }

  Future<void> _editPost() async {
    final post = _post;
    if (post == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublishPostPage(initialPost: post)),
    );
    if (saved == true && mounted) {
      setState(() => _isLoadingPost = true);
      await _loadPost();
    }
  }

  Future<void> _joinActivity() async {
    if (_activityBusy) return;
    setState(() => _activityBusy = true);
    try {
      await _entityService.joinActivity(widget.postId);
      await _loadActivityState();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已报名参与')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('报名失败：${_activityErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _activityBusy = false);
    }
  }

  Future<void> _cancelActivityJoin() async {
    if (_activityBusy) return;
    setState(() => _activityBusy = true);
    try {
      await _entityService.cancelActivityJoin(widget.postId);
      await _loadActivityState();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消报名')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _activityBusy = false);
    }
  }

  String _activityErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('人数已满')) return '活动人数已满';
    if (text.contains('报名已截止')) return '活动报名已截止';
    if (text.contains('活动已开始')) return '活动已开始';
    if (text.contains('不在招募状态')) return '活动不在招募中';
    if (text.contains('请先登录')) return '请先登录后报名';
    return '请稍后重试';
  }

  Future<void> _deletePost() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('删除后不可恢复，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _entityService.deleteEntity(widget.postId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('帖子已删除')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
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
          if (_post != null &&
              _post!.userId == Supabase.instance.client.auth.currentUser?.id)
            IconButton(
              onPressed: _editPost,
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined),
            ),
          if (_post != null &&
              _post!.userId == Supabase.instance.client.auth.currentUser?.id)
            IconButton(
              onPressed: _deleting ? null : _deletePost,
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
            ),
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

                if (_post!.entityType.startsWith('activity_'))
                  SliverToBoxAdapter(child: _buildActivityPanel()),

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
                    : _commentsError
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text('评论加载失败'),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() => _isLoadingComments = true);
                                    _loadComments();
                                  },
                                  child: const Text('重试'),
                                ),
                              ],
                            ),
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
                            onChanged: _loadComments,
                            onLikeChanged: () {
                              // 点赞状态由组件自身维护
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
                    if (_locationLabel().isNotEmpty)
                      Text(
                        _locationLabel(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                  final isVideo = m.mediaType == 'video';
                  final previewUrl = isVideo
                      ? (m.thumbnailUrl?.isNotEmpty == true
                            ? m.thumbnailUrl!
                            : null)
                      : m.url;
                  return Container(
                    margin: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (isVideo) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoPlayerPage(url: m.url),
                            ),
                          );
                        } else {
                          _openMediaGallery(imageUrls, index);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            if (previewUrl == null)
                              Container(
                                width: 300,
                                color: Colors.grey[300],
                                child: const Icon(Icons.videocam_outlined),
                              )
                            else
                              CachedNetworkImage(
                                imageUrl: previewUrl,
                                fit: BoxFit.cover,
                                width: 300,
                              ),
                            if (isVideo)
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    size: 56,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
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

  String _locationLabel() {
    final region = (_userProfile?['resident_region'] as String?)?.trim() ?? '';
    final resort = (_userProfile?['resident_resort'] as String?)?.trim() ?? '';
    return [
      if (region.isNotEmpty) region,
      if (resort.isNotEmpty && resort != '暂无固定雪场') resort,
    ].join(' · ');
  }

  Widget _buildActivityPanel() {
    final post = _post!;
    final extra = post.extraData;
    final region = extra['region_id']?.toString() ?? '未设置地区';
    final resort = extra['resort_id']?.toString() ?? '';
    final startAt = extra['start_at']?.toString() ?? '';
    final deadline = extra['join_deadline']?.toString() ?? '';
    final maxParticipants = extra['max_participants']?.toString() ?? '';
    final status = extra['activity_status']?.toString() ?? 'recruiting';

    final statusLabel = switch (status) {
      'recruiting' => '招募中',
      'full' => '已满员',
      'ended' => '已结束',
      'cancelled' => '已取消',
      _ => status,
    };

    final isOwn = post.userId == Supabase.instance.client.auth.currentUser?.id;
    final canJoin = status == 'recruiting' && !isOwn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '活动信息',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      statusLabel,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('地区：$region${resort.isEmpty ? '' : ' · $resort'}'),
              if (startAt.isNotEmpty) Text('开始时间：$startAt'),
              if (deadline.isNotEmpty) Text('报名截止：$deadline'),
              Text(
                maxParticipants.isEmpty
                    ? '已报名：$_participantCount 人'
                    : '已报名：$_participantCount / $maxParticipants 人',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _joinedActivity
                    ? OutlinedButton.icon(
                        onPressed: _activityBusy ? null : _cancelActivityJoin,
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text('取消报名'),
                      )
                    : FilledButton.icon(
                        onPressed: (_activityBusy || !canJoin)
                            ? null
                            : _joinActivity,
                        icon: const Icon(Icons.group_add_outlined),
                        label: Text(
                          isOwn ? '我发起的活动' : (canJoin ? '报名参与' : '当前不可报名'),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
