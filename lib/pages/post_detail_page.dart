import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../models/comment_model.dart';
import '../services/contact_service.dart';
import '../services/entity_service.dart';
import '../services/comment_service.dart';
import '../services/moderation_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/activity_form_sheets.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_sheet.dart';
import '../widgets/app/media_strip.dart';
import '../widgets/app/region_tag.dart';
import '../widgets/app/status_chip.dart';
import '../widgets/comment_input_sheet.dart';
import '../widgets/comment_item.dart';
import '../widgets/post_action_bar.dart';
import '../utils/geo_format.dart';
import '../utils/time_utils.dart';
import 'image_gallery_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'publish_post_page.dart';
import 'video_player_page.dart';
import '../utils/error_text.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  static const List<String> _reportReasons = <String>[
    '广告引流',
    '色情或暴力',
    '辱骂骚扰',
    '虚假内容',
    '其他',
  ];

  final EntityService _entityService = EntityService();
  final CommentService _commentService = CommentService();
  final ModerationService _moderationService = ModerationService();

  BaseEntity? _post;
  List<CommentModel> _comments = <CommentModel>[];
  Map<String, dynamic>? _authorProfile;

  bool _loadingPost = true;
  bool _loadingComments = true;
  bool _commentsError = false;

  bool _joined = false;
  bool _activityBusy = false;
  int _participantCount = 0;

  /// 当前用户对这个活动的申请记录（id + status）。
  Map<String, dynamic>? _myRequest;

  bool _deleting = false;

  bool get _isOwn =>
      _post != null &&
      _post!.userId == Supabase.instance.client.auth.currentUser?.id;

  bool get _isActivity => _post?.entityType.startsWith('activity_') ?? false;

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadComments();
  }

  Future<void> _loadPost() async {
    try {
      final post = await _entityService.fetchEntity(widget.postId);
      if (!mounted) return;
      if (post == null) {
        setState(() => _loadingPost = false);
        return;
      }
      final profile = await _getAuthorProfile(post.userId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _authorProfile = profile;
        _loadingPost = false;
      });
      if (post.entityType.startsWith('activity_')) {
        await _loadActivityState();
      }
    } catch (e) {
      debugPrint('加载内容失败: $e');
      if (mounted) setState(() => _loadingPost = false);
    }
  }

  Future<Map<String, dynamic>> _getAuthorProfile(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return row ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _loadActivityState() async {
    try {
      final rows = await Supabase.instance.client
          .from('activity_participants')
          .select('user_id, status')
          .eq('entity_id', widget.postId);
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      var joined = false;
      var count = 0;
      for (final row in rows as List) {
        if (row['status'] != 'joined') continue;
        count++;
        if (row['user_id'] == uid) joined = true;
      }
      final request = await _entityService.myActivityRequest(widget.postId);
      if (!mounted) return;
      setState(() {
        _participantCount = count;
        _joined = joined;
        _myRequest = request;
      });
    } catch (e) {
      debugPrint('加载报名状态失败: $e');
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _loadingComments = true;
      _commentsError = false;
    });
    try {
      final comments = await _commentService.getCommentTree(
        entityId: widget.postId,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    } catch (e) {
      debugPrint('加载评论失败: $e');
      if (!mounted) return;
      setState(() {
        _loadingComments = false;
        _commentsError = true;
      });
    }
  }

  int get _commentTotal {
    var total = 0;
    for (final comment in _comments) {
      total += 1 + comment.replies.length;
    }
    return total;
  }

  Future<void> _writeComment({CommentModel? replyTo}) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted || Supabase.instance.client.auth.currentSession == null) {
        return;
      }
    }
    if (!mounted) return;
    final created = await showCommentInputSheet(
      context,
      entityId: widget.postId,
      replyTo: replyTo,
    );
    if (created == null) return;
    await _loadComments();
  }

  /// 右上角「更多」：分享 / 举报 / 编辑 / 删除都收在这里，避免一排图标误触。
  Future<void> _openActions() async {
    final post = _post;
    if (post == null) return;
    await showAppSheet<void>(
      context,
      title: '帖子操作',
      builder: (sheetContext) => Column(
        children: [
          _DetailAction(
            icon: AppIcons.flag,
            label: '举报',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _report(targetType: 'entity', targetId: widget.postId);
            },
          ),
          if (_isOwn) ...[
            _DetailAction(
              icon: AppIcons.edit,
              label: '编辑',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _editPost();
              },
            ),
            _DetailAction(
              icon: AppIcons.trash,
              label: '删除',
              danger: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deletePost();
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editPost() async {
    final post = _post;
    if (post == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PublishPostPage(initialPost: post)),
    );
    if (saved == true && mounted) {
      setState(() => _loadingPost = true);
      await _loadPost();
    }
  }

  Future<void> _deletePost() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除内容'),
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
    setState(() => _deleting = true);
    try {
      await _entityService.deleteEntity(widget.postId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '删除失败'))),
      );
    }
  }

  Future<void> _report({
    required String targetType,
    required String targetId,
  }) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted || Supabase.instance.client.auth.currentSession == null) {
        return;
      }
    }
    if (!mounted) return;

    final detailsController = TextEditingController();
    String reason = _reportReasons.first;
    final submitted = await showAppSheet<bool>(
      context,
      title: targetType == 'entity' ? '举报内容' : '举报评论',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocalState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: '举报原因',
              requiredMark: true,
              child: AppDropdown<String>(
                options: [
                  for (final item in _reportReasons)
                    AppOption<String>(item, item),
                ],
                value: reason,
                onChanged: (value) =>
                    setLocalState(() => reason = value ?? _reportReasons.first),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '补充说明',
              note: '可选',
              child: AppTextField(
                controller: detailsController,
                hint: '描述具体问题，帮助管理员判断',
                minLines: 3,
                maxLines: 5,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            AppButton(
              label: '提交举报',
              expand: true,
              onPressed: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    final details = detailsController.text.trim();
    detailsController.dispose();
    if (submitted != true || !mounted) return;

    try {
      await _moderationService.report(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        details: details.isEmpty ? null : details,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('举报已提交')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('举报失败：${_reportMessage(e)}')));
    }
  }

  String _reportMessage(Object error) {
    final text = error.toString();
    if (text.contains('不能举报自己的内容')) return '不能举报自己的内容';
    if (text.contains('举报目标不存在')) return '该内容已不存在';
    if (text.contains('操作过于频繁')) return '提交过于频繁，请稍后再试';
    if (text.contains('23505')) return '你已经提交过类似举报';
    return '请稍后再试';
  }

  /// 申请参与：先补手机号 -> 二次确认 -> 提交申请。
  Future<void> _requestJoin() async {
    if (_activityBusy) return;
    if (Supabase.instance.client.auth.currentSession == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    var phone = await ContactService().loadMine();
    if (!mounted) return;
    if (phone == null) {
      phone = await showPhoneSheet(
        context,
        title: '填写手机号',
        hint: '参与活动需要手机号，对方同意后你们可以互相联系。',
      );
      if (phone == null) return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认申请参与？'),
        content: Text(
          '你的手机号 ${ContactService.mask(phone!)} 会提供给发起者，'
          '方便你们碰头。对方同意后你也能看到对方的号码。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('否'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('是'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _activityBusy = true);
    try {
      await _entityService.requestJoinActivity(widget.postId);
      await _loadActivityState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发送参与申请，等对方确认')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_joinMessage(e))));
    } finally {
      if (mounted) setState(() => _activityBusy = false);
    }
  }

  Future<void> _cancelJoin() async {
    if (_activityBusy) return;
    setState(() => _activityBusy = true);
    try {
      await _entityService.cancelActivityRequest(widget.postId);
      await _loadActivityState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已取消，人数已释放')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_joinMessage(e))));
    } finally {
      if (mounted) setState(() => _activityBusy = false);
    }
  }

  /// 查看对方手机号：申请人需被同意，发起者随时可看。
  Future<void> _showContact() async {
    final requestId = _myRequest?['id']?.toString();
    if (requestId == null || requestId.isEmpty) return;
    try {
      final phone = await _entityService.activityContact(requestId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('联系电话'),
          content: SelectableText(
            phone,
            style: AppText.pageTitle.copyWith(
              color: Theme.of(dialogContext).colorScheme.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '暂时拿不到手机号'))),
      );
    }
  }

  String _joinMessage(Object error) {
    final text = error.toString();
    if (text.contains('人数已满')) return '活动人数已满';
    if (text.contains('活动已开始')) return '活动已开始';
    if (text.contains('手机号')) return '请先填写手机号';
    if (text.contains('自己')) return '这是你自己发起的活动';
    if (text.contains('不在招募状态')) return '活动当前不在招募中';
    if (text.contains('请先登录')) return '请先登录后报名';
    return '请稍后再试';
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isActivity ? '活动详情' : '帖子详情'),
        actions: [
          Semantics(
            button: true,
            label: '更多操作',
            child: IconButton(
              tooltip: '更多操作',
              onPressed: _deleting ? null : _openActions,
              icon: const Icon(AppIcons.more),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _post == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.lg,
                  AppSpace.md,
                ),
                child: _CommentEntryBar(onTap: _writeComment),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loadingPost) {
      return const Center(child: CircularProgressIndicator());
    }
    final post = _post;
    if (post == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('内容不存在或已被删除'),
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: '返回',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }

    final colors = context.colors;
    final nickname = (_authorProfile?['nickname'] as String?)?.trim();
    final avatarUrl = _authorProfile?['avatar_url'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.md,
        AppSpace.xl,
        AppSpace.xl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: '查看作者主页',
              child: GestureDetector(
                onTap: () => _openProfile(post.userId),
                child: AppAvatar(url: avatarUrl, size: AppSize.avatar),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openProfile(post.userId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            (nickname == null || nickname.isEmpty)
                                ? '雪友'
                                : nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title.copyWith(color: colors.ink),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          TimeUtils.formatRelativeTime(post.createdAt),
                          style: AppText.meta.copyWith(color: colors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    RegionTag(
                      region: _authorProfile?['resident_region'] as String?,
                      resort: _authorProfile?['resident_resort'] as String?,
                      plain: true,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xxl),
        Text(post.title, style: AppText.display.copyWith(color: colors.ink)),
        if ((post.content ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            post.content!.trim(),
            style: AppText.body.copyWith(color: colors.ink),
          ),
        ],
        if (post.media.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          MediaStrip(
            media: post.media,
            height: 300,
            itemWidthFactor: 0.96,
            onOpenImage: (urls, index) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ImageGalleryPage(imageUrls: urls, initialIndex: index),
              ),
            ),
            onOpenVideo: (media) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerPage(url: media.url),
              ),
            ),
          ),
        ],
        if (_isActivity) ...[
          const SizedBox(height: AppSpace.xl),
          _buildActivityCard(post),
        ],
        const SizedBox(height: AppSpace.md),
        PostActionBar(
          postId: widget.postId,
          onShare: () {
            final post = _post;
            if (post == null) return;
            ShareService.shareEntity(context, post);
          },
        ),
        const SizedBox(height: AppSpace.sm),
        Divider(color: colors.line, height: 1),
        const SizedBox(height: AppSpace.lg),
        Text(
          '评论 ($_commentTotal)',
          style: AppText.title.copyWith(color: colors.ink),
        ),
        const SizedBox(height: AppSpace.sm),
        if (_loadingComments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_commentsError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
            child: Column(
              children: [
                Text(
                  '评论加载失败',
                  style: AppText.bodySmall.copyWith(color: colors.muted),
                ),
                const SizedBox(height: AppSpace.md),
                AppButton(
                  label: '重试',
                  variant: AppButtonVariant.outline,
                  dense: true,
                  onPressed: _loadComments,
                ),
              ],
            ),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: Center(
              child: Text(
                '还没有评论',
                style: AppText.bodySmall.copyWith(color: colors.muted),
              ),
            ),
          )
        else
          for (final comment in _comments)
            CommentItem(
              key: ValueKey(comment.id),
              comment: comment,
              onReplyPressed: () => _writeComment(replyTo: comment),
              onDeleted: (_) => _loadComments(),
              onChanged: _loadComments,
              onAuthorTap: _openProfile,
              onReportPressed: () =>
                  _report(targetType: 'comment', targetId: comment.id),
            ),
      ],
    );
  }

  Widget _buildActivityCard(BaseEntity post) {
    final colors = context.colors;
    final extra = post.extraData;
    final region = extra['region_id']?.toString().trim() ?? '';
    final resort = extra['resort_id']?.toString().trim() ?? '';
    final place = shortRegionLabel(region: region, resort: resort);
    final startRaw = extra['start_at']?.toString() ?? '';
    final maxRaw = extra['max_participants']?.toString() ?? '';
    final status = extra['activity_status']?.toString() ?? 'recruiting';

    final startAt = DateTime.tryParse(startRaw);
    final maxParticipants = int.tryParse(maxRaw);
    final now = DateTime.now();

    final ended = status == 'ended' || status == 'cancelled';
    final started = startAt != null && startAt.isBefore(now);
    final isFull =
        status == 'full' ||
        (maxParticipants != null && _participantCount >= maxParticipants);

    final requestStatus = _myRequest?['status']?.toString() ?? '';
    final pending = requestStatus == 'pending';
    final accepted = requestStatus == 'accepted';
    final declined = requestStatus == 'declined';

    late final String actionLabel;
    late final bool canAct;
    late final VoidCallback onAction;
    if (_isOwn) {
      actionLabel = '我发起的活动';
      canAct = false;
      onAction = () {};
    } else if (accepted) {
      actionLabel = '取消参加';
      canAct = !ended && !started;
      onAction = _cancelJoin;
    } else if (pending) {
      actionLabel = '已申请，等对方确认';
      canAct = false;
      onAction = () {};
    } else if (ended || started) {
      actionLabel = started ? '活动已开始' : '活动已结束';
      canAct = false;
      onAction = () {};
    } else if (isFull) {
      actionLabel = '已满员';
      canAct = false;
      onAction = () {};
    } else {
      actionLabel = declined ? '再申请一次' : '申请参与';
      canAct = true;
      onAction = _requestJoin;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ActivityStatusChip(status: status),
              const Spacer(),
              if (place.isNotEmpty)
                Flexible(
                  child: Text(
                    place,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(color: colors.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          _InfoRow(
            label: '开始时间',
            value: startRaw.isEmpty ? '未设置' : _prettyDate(startRaw),
          ),
          const SizedBox(height: AppSpace.md),
          _InfoRow(
            label: '参与人数',
            value: maxParticipants == null
                ? '$_participantCount 人'
                : '$_participantCount / $maxParticipants 人',
          ),
          if (pending) ...[
            const SizedBox(height: AppSpace.md),
            _InfoRow(label: '我的申请', value: '已发送，等对方处理'),
          ],
          if (declined) ...[
            const SizedBox(height: AppSpace.md),
            _InfoRow(label: '我的申请', value: '对方婉拒了，可以再申请一次'),
          ],
          const SizedBox(height: AppSpace.xl),
          AppButton(
            label: actionLabel,
            expand: true,
            icon: accepted ? AppIcons.close : AppIcons.group,
            loading: _activityBusy,
            variant: canAct ? AppButtonVariant.solid : AppButtonVariant.outline,
            onPressed: canAct ? onAction : null,
          ),
          if (pending && !_isOwn) ...[
            const SizedBox(height: AppSpace.sm),
            Center(
              child: TextButton(
                onPressed: _activityBusy ? null : _cancelJoin,
                child: const Text('撤回申请'),
              ),
            ),
          ],
          if (accepted) ...[
            const SizedBox(height: AppSpace.sm),
            AppButton(
              label: '查看对方手机号',
              expand: true,
              variant: AppButtonVariant.outline,
              icon: AppIcons.person,
              onPressed: _showContact,
            ),
          ],
        ],
      ),
    );
  }

  String _prettyDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: AppText.bodySmall.copyWith(color: colors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppText.bodySmall.copyWith(color: colors.ink),
          ),
        ),
      ],
    );
  }
}

class _CommentEntryBar extends StatelessWidget {
  const _CommentEntryBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '写评论',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          decoration: BoxDecoration(
            color: colors.soft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(AppIcons.comment, size: 18, color: colors.muted),
              const SizedBox(width: AppSpace.sm),
              Text('写评论…', style: AppText.body.copyWith(color: colors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = danger ? colors.danger : colors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpace.md),
            Text(label, style: AppText.body.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
