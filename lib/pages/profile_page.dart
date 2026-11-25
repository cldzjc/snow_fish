import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../models/user_profile.dart';
import '../services/entity_service.dart';
import '../services/moderation_service.dart';
import '../services/my_profile_store.dart';
import '../services/profile_sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/app/region_tag.dart';
import 'admin_center_page.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'my_content_page.dart';
import 'my_posts_page.dart';
import 'notifications_page.dart';
import 'post_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.userId});

  final String? userId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient _client = Supabase.instance.client;
  final EntityService _entityService = EntityService();
  final ModerationService _moderationService = ModerationService();

  UserProfile? _profile;
  List<BaseEntity> _posts = <BaseEntity>[];
  bool _loading = true;
  String? _error;

  String? get _targetUserId => widget.userId ?? _client.auth.currentUser?.id;

  bool get _isOwn =>
      widget.userId == null || widget.userId == _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    MyProfileStore.changedTick.addListener(_onProfileChanged);
    _load();
  }

  @override
  void dispose() {
    MyProfileStore.changedTick.removeListener(_onProfileChanged);
    super.dispose();
  }

  /// 自己的资料在别处被改过（例如首页切换了常驻地点），这里补齐。
  void _onProfileChanged() {
    if (!mounted || !_isOwn) return;
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final userId = _targetUserId;
    if (userId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isOwn) {
        await ProfileSyncService().ensureCurrentProfile();
      }
      final profileFuture = _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      final postsFuture = _entityService.fetchUserEntities(
        userId: userId,
        type: 'post',
      );
      final results = await Future.wait<dynamic>([profileFuture, postsFuture]);
      final profileRow = results[0] as Map<String, dynamic>?;
      final posts = results[1] as List<BaseEntity>;
      if (!mounted) return;
      setState(() {
        _profile = profileRow == null
            ? UserProfile(id: userId, updatedAt: DateTime.now())
            : UserProfile.fromJson(Map<String, dynamic>.from(profileRow));
        _posts = posts;
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

  Future<void> _editProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (updated == true) await _load();
  }

  Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('退出失败：$e')));
    }
  }

  Future<void> _blockUser() async {
    final userId = _targetUserId;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('拉黑这位雪友？'),
        content: const Text('拉黑后，你将不再看到对方的内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('拉黑'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _moderationService.blockUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已拉黑该用户')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  void _open(MyContentKind kind) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyContentPage(kind: kind)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwn ? '我的' : '雪友主页'),
        actions: [
          if (_client.auth.currentUser != null && _isOwn)
            IconButton(
              tooltip: '通知',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
              icon: const Icon(AppIcons.bell),
            ),
          if (_client.auth.currentUser != null && _isOwn)
            IconButton(
              tooltip: '退出登录',
              onPressed: _signOut,
              icon: const Icon(AppIcons.logout),
            ),
          if (!_isOwn)
            IconButton(
              tooltip: '拉黑',
              onPressed: _blockUser,
              icon: const Icon(AppIcons.block),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingSkeleton(rows: 2);
    if (_error != null) return AppStateView.error(onRetry: _load);
    if (_targetUserId == null) {
      return AppStateView.login(
        onLogin: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 92),
        children: [
          _buildHeader(),
          if (_isOwn) _buildEntries(),
          _buildPostSection(),
          const SizedBox(height: AppSpace.xxxl),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;
    final profile = _profile;
    final name = (profile?.nickname?.trim().isNotEmpty ?? false)
        ? profile!.nickname!.trim()
        : '匿名用户';
    final bio = (profile?.bio?.trim().isNotEmpty ?? false)
        ? profile!.bio!.trim()
        : '这个人还没有签名';
    final cover = profile?.backgroundUrl?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: cover.isEmpty
              ? Container(color: colors.soft)
              : CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(color: colors.soft),
                  errorWidget: (_, __, ___) => Container(color: colors.soft),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colors.paper,
                        shape: BoxShape.circle,
                      ),
                      child: AppAvatar(url: profile?.avatarUrl, size: 56),
                    ),
                    const Spacer(),
                    if (_isOwn)
                      AppButton(
                        label: '编辑资料',
                        variant: AppButtonVariant.outline,
                        dense: true,
                        onPressed: _editProfile,
                      )
                    else
                      AppButton(
                        label: '举报',
                        variant: AppButtonVariant.outline,
                        dense: true,
                        icon: AppIcons.flag,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请在该雪友的帖子内举报具体内容')),
                            ),
                      ),
                  ],
                ),
              ),
              Text(name, style: AppText.display.copyWith(color: colors.ink)),
              const SizedBox(height: AppSpace.sm),
              Text(bio, style: AppText.body.copyWith(color: colors.ink)),
              const SizedBox(height: AppSpace.sm),
              RegionTag(
                region: profile?.residentRegion,
                resort: profile?.residentResort,
              ),
              const SizedBox(height: AppSpace.lg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntries() {
    final colors = context.colors;
    final entries = <_Entry>[
      _Entry(
        '我的帖子',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyPostsPage()),
        ),
      ),
      _Entry('我的评论', () => _open(MyContentKind.comments)),
      _Entry('我的收藏', () => _open(MyContentKind.favorites)),
      _Entry('我的活动', () => _open(MyContentKind.activities)),
      _Entry('社区服务', () => _open(MyContentKind.community)),
      _Entry('关于 Snow Fish', () => _open(MyContentKind.about)),
      _Entry('设置', () => _open(MyContentKind.settings)),
      if (_profile?.role == 'admin')
        _Entry(
          '内容治理中心',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminCenterPage()),
          ),
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.line),
          bottom: BorderSide(color: colors.line),
        ),
      ),
      child: Column(
        children: [
          for (final entry in entries)
            InkWell(
              onTap: entry.onTap,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: entry == entries.last
                          ? Colors.transparent
                          : colors.line,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label,
                        style: AppText.body.copyWith(color: colors.ink),
                      ),
                    ),
                    Icon(AppIcons.chevron, size: 18, color: colors.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostSection() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.xxl,
        AppSpace.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isOwn ? '我发布的动态' : 'TA 发布的动态',
            style: AppText.title.copyWith(color: colors.ink),
          ),
          const SizedBox(height: AppSpace.md),
          if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
              child: Center(
                child: Text(
                  '还没有发布动态',
                  style: AppText.bodySmall.copyWith(color: colors.muted),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: Column(
                children: [
                  for (final post in _posts)
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(postId: post.id),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: colors.line),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.lg,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.title,
                                    style: AppText.body.copyWith(
                                      color: colors.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    (post.content ?? '').trim().isEmpty
                                        ? '无正文'
                                        : post.content!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.bodySmall.copyWith(
                                      color: colors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    TimeUtils.formatRelativeTime(
                                      post.createdAt,
                                    ),
                                    style: AppText.caption.copyWith(
                                      color: colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              AppIcons.chevron,
                              size: 18,
                              color: colors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}
