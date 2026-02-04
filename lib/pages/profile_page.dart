import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'login_page.dart';
import 'register_page.dart';
import 'my_products_page.dart';
import 'edit_profile_page.dart';
import 'my_videos_page.dart';
import '../models/user_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  UserProfile? _userProfile;
  String? _videoUrl;

  VideoPlayerController? _videoController;
  Future<void>? _initVideoFuture;

  bool _isLoggedIn() => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    // 从 user_profiles 表获取用户数据
    final res = await Supabase.instance.client
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    if (res == null) {
      setState(() => _loading = false);
      return;
    }

    final data = res;
    final profile = UserProfile.fromJson(data);

    setState(() {
      _userProfile = profile;
      _loading = false;
    });

    // 如果有视频，初始化视频播放器（当前架构中暂未使用）
    if (_videoUrl != null && _videoUrl!.isNotEmpty) {
      _videoController = VideoPlayerController.network(_videoUrl!);
      _initVideoFuture = _videoController!.initialize();
      if (mounted) setState(() {});
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    if (updated == true) {
      await _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
      _initVideoFuture = null;
      _fetchUserProfile();
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已退出登录')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('退出失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: _isLoggedIn()
            ? [
                IconButton(onPressed: _openEdit, icon: const Icon(Icons.edit)),
                IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isLoggedIn()
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile header
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 背景图 - 使用 CachedNetworkImage 加载
                      SizedBox(
                        height: 180,
                        child: Stack(
                          children: [
                            // 背景图片
                            if (_userProfile?.backgroundUrl != null &&
                                _userProfile!.backgroundUrl!.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: _userProfile!.backgroundUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) {
                                  debugPrint(
                                    'Background image load error: $error (url=${_userProfile?.backgroundUrl})',
                                  );
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Text(
                                        '背景图加载失败',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ),
                                  );
                                },
                              )
                            else
                              Container(color: Colors.grey[200]),
                            // 编辑背景的按钮
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                  onPressed: _openEdit,
                                  tooltip: '编辑背景',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 头像
                            CircleAvatar(
                              radius: 36,
                              backgroundImage:
                                  _userProfile?.avatarUrl != null &&
                                      _userProfile!.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      _userProfile!.avatarUrl!,
                                    )
                                  : null,
                              child:
                                  (_userProfile?.avatarUrl == null ||
                                      _userProfile!.avatarUrl!.isEmpty)
                                  ? const Icon(Icons.person, size: 36)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userProfile?.nickname ?? '未设置昵称',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _userProfile?.bio ?? '还没有个人简介',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_videoUrl != null &&
                          _videoUrl!.isNotEmpty &&
                          _videoController != null)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: FutureBuilder(
                            future: _initVideoFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                return AspectRatio(
                                  aspectRatio:
                                      _videoController!.value.aspectRatio,
                                  child: Stack(
                                    children: [
                                      VideoPlayer(_videoController!),
                                      GestureDetector(
                                        onTap: () =>
                                            _videoController!.value.isPlaying
                                            ? _videoController!.pause()
                                            : _videoController!.play(),
                                        child: const Center(
                                          child: Icon(
                                            Icons.play_circle_fill,
                                            size: 48,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                return const SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // 编辑资料按钮（主按钮）
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑资料'),
                    onPressed: _openEdit,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  '我的功能',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                ListTile(
                  leading: const Icon(Icons.inventory),
                  title: const Text('我发布的商品'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyProductsPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.video_collection),
                  title: const Text('我的视频'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyVideosPage(),
                    ),
                  ),
                ),

                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('编辑个人资料'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openEdit,
                ),
              ],
            )
          : _buildLoggedOutView(),
    );
  }

  Widget _buildLoggedOutView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              '欢迎使用二手交易平台',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '登录后即可发布商品、查看订单、管理个人资料',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('登录账户'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('创建账户'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '登录后享受更多功能',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
