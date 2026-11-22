import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../models/user_profile.dart';
import '../services/entity_service.dart';
import '../services/moderation_service.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'post_detail_page.dart';
import 'register_page.dart';
import 'admin_center_page.dart';
import 'notifications_page.dart';
import '../services/profile_sync_service.dart';
import 'my_posts_page.dart';
import 'my_content_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _client = Supabase.instance.client;
  final _entityService = EntityService();
  final _moderationService = ModerationService();
  UserProfile? _profile;
  List<BaseEntity> _posts = [];
  bool _loading = true;
  String? _error;

  String? get _targetUserId => widget.userId ?? _client.auth.currentUser?.id;

  bool get _isOwnProfile =>
      widget.userId == null || widget.userId == _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final userId = _targetUserId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      if (_isOwnProfile) {
        await ProfileSyncService().ensureCurrentProfile();
      }

      final profileFuture = () async {
        return await _client
            .from('user_profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
      }();
      final postsFuture = _entityService.fetchUserEntities(
        userId: userId,
        type: 'post',
      );
      final results = await Future.wait<dynamic>([profileFuture, postsFuture]);
      final profile = results[0] as Map<String, dynamic>?;
      final posts = results[1] as List<BaseEntity>;
      if (!mounted) return;
      setState(() {
        _profile = profile == null
            ? UserProfile(id: userId, updatedAt: DateTime.now())
            : UserProfile.fromJson(Map<String, dynamic>.from(profile));
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (updated == true) _loadProfile();
  }

  Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('退出失败: $e')));
      }
    }
  }

  Future<void> _blockUser() async {
    final userId = _targetUserId;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拉黑用户？'),
        content: const Text('拉黑后将不再主动看到该用户的内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('拉黑'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _moderationService.blockUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已拉黑该用户')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isOwnProfile ? '我的主页' : '用户主页';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: _client.auth.currentUser != null
            ? [
                if (!_isOwnProfile)
                  IconButton(
                    onPressed: _blockUser,
                    tooltip: '拉黑',
                    icon: const Icon(Icons.block),
                  ),
                if (_isOwnProfile)
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    ),
                    tooltip: '通知',
                    icon: const Icon(Icons.notifications_none),
                  ),
                if (_isOwnProfile)
                  IconButton(
                    onPressed: _signOut,
                    tooltip: '退出登录',
                    icon: const Icon(Icons.logout),
                  ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _targetUserId == null
          ? _buildLoggedOut()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  if (_isOwnProfile) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑资料'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyPostsPage(),
                            ),
                          ),
                          child: const Text('我的帖子'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyContentPage(
                                kind: MyContentKind.comments,
                              ),
                            ),
                          ),
                          child: const Text('我的评论'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyContentPage(
                                kind: MyContentKind.favorites,
                              ),
                            ),
                          ),
                          child: const Text('我的收藏'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyContentPage(
                                kind: MyContentKind.activities,
                              ),
                            ),
                          ),
                          child: const Text('我的活动'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyContentPage(
                                kind: MyContentKind.community,
                              ),
                            ),
                          ),
                          child: const Text('社区服务'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyContentPage(
                                kind: MyContentKind.about,
                              ),
                            ),
                          ),
                          child: const Text('关于 Snow Fish'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyContentPage(
                                kind: MyContentKind.settings,
                              ),
                            ),
                          ),
                          child: const Text('设置'),
                        ),
                      ],
                    ),
                    if (_profile?.role == 'admin') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminCenterPage(),
                          ),
                        ),
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('内容治理中心'),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Text(
                    '${_isOwnProfile ? '我' : 'TA'}发布的动态',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('还没有发布动态')),
                    )
                  else
                    ..._posts.map(_buildPostCard),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final profile = _profile;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: profile?.backgroundUrl?.isNotEmpty == true
                ? CachedNetworkImage(
                    imageUrl: profile!.backgroundUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.blueGrey.shade100),
                  )
                : Container(color: Colors.blueGrey.shade100),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundImage: profile?.avatarUrl?.isNotEmpty == true
                      ? CachedNetworkImageProvider(profile!.avatarUrl!)
                      : null,
                  child: profile?.avatarUrl?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.nickname?.trim().isNotEmpty == true
                            ? profile!.nickname!
                            : '匿名用户',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile?.bio?.trim().isNotEmpty == true
                            ? profile!.bio!
                            : '这个人还没有签名',
                      ),
                      if ((profile?.residentRegion?.isNotEmpty == true ||
                          profile?.residentResort?.isNotEmpty == true &&
                              profile?.residentResort != '暂无固定雪场'))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            [
                              if (profile?.residentRegion?.isNotEmpty == true)
                                profile!.residentRegion!,
                              if (profile?.residentResort?.isNotEmpty == true &&
                                  profile?.residentResort != '暂无固定雪场')
                                profile!.residentResort!,
                            ].join(' · '),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BaseEntity post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(post.title),
        subtitle: Text(
          post.content?.trim().isNotEmpty == true ? post.content! : '无正文',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailPage(postId: post.id)),
        ),
      ),
    );
  }

  Widget _buildLoggedOut() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('登录后管理个人资料并发布动态'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            child: const Text('登录'),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            ),
            child: const Text('注册'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('用户主页加载失败'),
        TextButton(onPressed: _loadProfile, child: const Text('重试')),
      ],
    ),
  );
}
