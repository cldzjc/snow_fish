import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_tabs.dart';
import '../widgets/app/brand_mark.dart';
import '../widgets/app/immersive.dart';
import '../widgets/app/lottie_pull_refresh.dart';
import 'activity_list_widget.dart';
import 'login_page.dart';
import 'posts_list_widget.dart';
import 'profile_page.dart';

/// 首页当前是否停留在「约约约」，供底部发布入口判断默认发布类型。
final ValueNotifier<bool> homeActivityTabActive = ValueNotifier<bool>(false);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabs = <String>['sk社区', '约约约'];

  final GlobalKey<PostsListWidgetState> _postsKey =
      GlobalKey<PostsListWidgetState>();
  final GlobalKey<ActivityListWidgetState> _activityKey =
      GlobalKey<ActivityListWidgetState>();

  /// 顶栏 logo 与下拉刷新共用同一个进度：0 = 完整 logo，0.44 = 擦净。
  late final AnimationController _brandAnim = AnimationController(
    vsync: this,
    value: 0,
    duration: const Duration(milliseconds: 720),
  );

  int _index = 0;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    homeActivityTabActive.value = _index == 1;
    _loadProfile();
  }

  @override
  void dispose() {
    homeActivityTabActive.value = false;
    _brandAnim.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _profile = null);
      return;
    }
    // 先用登录态兜底，避免头像区闪烁。
    if (mounted) {
      setState(
        () => _profile = <String, dynamic>{
          'nickname': user.userMetadata?['nickname'] ?? '',
          'avatar_url': user.userMetadata?['avatar_url'] ?? '',
        },
      );
    }
    try {
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() => _profile = row);
    } catch (_) {
      // 资料读取失败不影响首页展示。
    }
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    homeActivityTabActive.value = index == 1;
    immersiveHidden.value = false;
  }

  /// 刷新当前板块的数据，等真实请求结束再收起指示器。
  Future<void> _refreshCurrent() {
    final future = _index == 1
        ? _activityKey.currentState?.refreshNow()
        : _postsKey.currentState?.refreshNow();
    return future ?? Future<void>.value();
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (mounted) await _loadProfile();
  }

  Future<void> _openMyProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      await _openLogin();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
    );
    if (mounted) await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ImmersiveHide(child: _buildTopBar()),
            Expanded(
              child: LottiePullRefresh(
                controller: _brandAnim,
                onRefresh: _refreshCurrent,
                child: Column(
                  children: [
                    ImmersiveHide(
                      child: AppTabs(
                        tabs: _tabs,
                        index: _index,
                        onChanged: _select,
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: [
                          PostsListWidget(key: _postsKey),
                          ActivityListWidget(key: _activityKey),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏：左侧当前用户，中间品牌标志（下拉时笔迹会被擦掉）。
  Widget _buildTopBar() {
    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          Center(child: BrandMarkLottie(controller: _brandAnim, height: 34)),
          Positioned(
            left: 10,
            top: 0,
            bottom: 0,
            child: Center(child: _buildUserChip()),
          ),
        ],
      ),
    );
  }

  Widget _buildUserChip() {
    final colors = context.colors;
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    final nickname = (_profile?['nickname'] as String?)?.trim();
    final name = !loggedIn
        ? '登录'
        : ((nickname == null || nickname.isEmpty) ? '雪友' : nickname);
    final avatarUrl = loggedIn ? (_profile?['avatar_url'] as String?) : null;

    return Semantics(
      button: true,
      label: loggedIn ? '$name 的主页' : '登录',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: loggedIn ? _openMyProfile : _openLogin,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(url: avatarUrl, size: 30),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 84),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
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
