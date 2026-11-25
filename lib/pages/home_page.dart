import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/geo.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_tabs.dart';
import '../widgets/app/brand_mark.dart';
import '../widgets/app/geo_picker_sheet.dart';
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

  static const double _brandBarHeight = 58;
  static const double _tabsHeight = 42;
  static const double headerHeight = _brandBarHeight + _tabsHeight;

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
    revealChrome();
  }

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

  /// 点击地区标签：切换的是「浏览用」的常驻地区，可以顺便写回资料。
  Future<void> _switchRegion() async {
    final selection = await showGeoPicker(
      context,
      title: '我的常驻地点',
      initialRegion: _profile?['resident_region'] as String?,
      initialResort: _profile?['resident_resort'] as String?,
    );
    if (selection == null || !mounted) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    setState(() {
      _profile = <String, dynamic>{
        ...?_profile,
        'resident_region': selection.region,
        'resident_resort': selection.resort,
      };
    });
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'resident_region': selection.region,
            'resident_resort': selection.resort,
          })
          .eq('id', userId);
      if (!mounted) return;
      _postsKey.currentState?.refreshNow();
      _activityKey.currentState?.refreshNow();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('常驻地点已更新为 ${selection.display}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('地点更新失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: LottiePullRefresh(
                controller: _brandAnim,
                onRefresh: _refreshCurrent,
                // 顶部栏是浮层，内容顶部留出等高的空白，滚到下面时被内容盖住。
                child: Padding(
                  padding: const EdgeInsets.only(top: headerHeight),
                  child: IndexedStack(
                    index: _index,
                    children: [
                      PostsListWidget(key: _postsKey),
                      ActivityListWidget(key: _activityKey),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: ImmersiveHide(
                hideOffset: const Offset(0, -headerHeight),
                child: Container(
                  color: colors.paper,
                  child: Column(
                    children: [
                      _buildBrandBar(),
                      AppTabs(
                        tabs: _tabs,
                        index: _index,
                        onChanged: _select,
                        height: _tabsHeight,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 品牌标识栏：左用户、中 logo、右常驻地点。
  ///
  /// 左右两栏给固定宽度，中间 logo 用 Expanded 居中，
  /// 这样任何屏幕宽度下三者都不会互相压盖。
  static const double _sideSlot = 112;

  Widget _buildBrandBar() {
    return SizedBox(
      height: _brandBarHeight,
      child: Row(
        children: [
          SizedBox(width: 52, child: Center(child: _buildUserChip())),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BrandMarkLottie(controller: _brandAnim, height: 40),
              ),
            ),
          ),
          SizedBox(
            width: _sideSlot,
            child: Center(child: _buildRegionChip()),
          ),
        ],
      ),
    );
  }

  Widget _buildUserChip() {
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    final avatarUrl = loggedIn ? (_profile?['avatar_url'] as String?) : null;

    return Semantics(
      button: true,
      label: loggedIn ? '我的主页' : '登录',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: loggedIn ? _openMyProfile : _openLogin,
        child: Padding(
          padding: const EdgeInsets.only(left: 6, right: 4),
          child: AppAvatar(url: avatarUrl, size: 32),
        ),
      ),
    );
  }

  /// 常驻地点胶囊：图标 + 地区，点击可切换。
  Widget _buildRegionChip() {
    final colors = context.colors;
    final geo = GeoRepository.instance;
    final region = (_profile?['resident_region'] as String?)?.trim() ?? '';
    final resort = (_profile?['resident_resort'] as String?)?.trim() ?? '';
    // 只显示最末一级行政区 + 雪场，例如「崇礼·富龙」，避免胶囊过长。
    final parts = <String>[
      if (region.isNotEmpty) region.split('·').last.trim(),
      if (resort.isNotEmpty && resort != geo.noFixedResort) resort,
    ];
    final label = parts.isEmpty ? '选择地点' : parts.join('·');

    return Semantics(
      button: true,
      label: '切换常驻地点，当前 $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _switchRegion,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 12,
                child: SvgPicture.asset(
                  'assets/brand/icon_region.svg',
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(colors.muted, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.muted,
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
