import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/geo.dart';
import '../models/refresh_result.dart';
import '../services/my_profile_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_tabs.dart';
import '../widgets/app/brand_mark.dart';
import '../widgets/app/geo_picker_sheet.dart';
import '../widgets/app/immersive.dart';
import '../widgets/app/lottie_pull_refresh.dart';
import 'activity_list_widget.dart';
import 'circle_feed_widget.dart';
import 'login_page.dart';
import 'posts_list_widget.dart';
import 'profile_page.dart';
import '../utils/error_text.dart';

/// 首页当前是否停留在「约约约」，供底部发布入口判断默认发布类型。
final ValueNotifier<bool> homeActivityTabActive = ValueNotifier<bool>(false);

/// 首页当前是否停留在「圈」，发布时据此决定归属。
final ValueNotifier<bool> homeCircleTabActive = ValueNotifier<bool>(false);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const double _brandBarHeight = 58;
  static const double _tabsHeight = 42;
  static const double headerHeight = _brandBarHeight + _tabsHeight;

  final GlobalKey<PostsListWidgetState> _postsKey =
      GlobalKey<PostsListWidgetState>();
  final GlobalKey<ActivityListWidgetState> _activityKey =
      GlobalKey<ActivityListWidgetState>();
  final GlobalKey<CircleFeedWidgetState> _circleKey =
      GlobalKey<CircleFeedWidgetState>();

  /// 顶栏 logo 与下拉刷新共用同一个进度：0 = 完整 logo，0.44 = 擦净。
  late final AnimationController _brandAnim = AnimationController(
    vsync: this,
    value: 0,
    duration: const Duration(milliseconds: 720),
  );

  int _index = 0;

  @override
  void initState() {
    super.initState();
    homeActivityTabActive.value = false;
    homeCircleTabActive.value = false;
    MyProfileStore.load();
  }

  @override
  void dispose() {
    homeActivityTabActive.value = false;
    homeCircleTabActive.value = false;
    _brandAnim.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    homeActivityTabActive.value = index == 2;
    homeCircleTabActive.value = index == 1;
    revealChrome();
  }

  /// Tab 文案：中间那个显示当前浏览的圈，没入圈时是「?圈」。
  List<String> _tabLabels() {
    final circle =
        activeCircleForPublish.value ?? MyProfileStore.circle?.district;
    return <String>['sk社区', circle?.label ?? '?圈', '约约约'];
  }

  /// 下拉刷新当前板块，完成后提示「新增了几条」。
  Future<void> _refreshCurrent() async {
    final RefreshResult? result;
    final String unit;
    if (_index == 2) {
      result = await _activityKey.currentState?.refreshNow();
      unit = '个活动';
    } else if (_index == 1) {
      result = await _circleKey.currentState?.refreshNow();
      unit = '篇帖子';
    } else {
      result = await _postsKey.currentState?.refreshNow();
      unit = '篇帖子';
    }
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message(unit: unit)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (mounted) await MyProfileStore.load();
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
    if (mounted) await MyProfileStore.load();
  }

  /// 点击地区标签：切换常驻地点并广播，所有页面立即同步。
  Future<void> _switchRegion() async {
    final current = MyProfileStore.value;
    final selection = await showGeoPicker(
      context,
      title: '我的常驻地点',
      initialRegion: current?['resident_region'] as String?,
      initialResort: current?['resident_resort'] as String?,
    );
    if (selection == null || !mounted) return;

    try {
      await MyProfileStore.updateLocation(
        region: selection.region,
        resort: selection.resort,
      );
      if (!mounted) return;
      // 作者标签、约约约默认地区都跟着刷新。
      _postsKey.currentState?.reloadProfiles();
      _activityKey.currentState?.refreshNow();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('常驻地点已更新为 ${selection.display}')),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '地点更新失败'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            MyProfileStore.profile,
            activeCircleForPublish,
          ]),
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: LottiePullRefresh(
                  controller: _brandAnim,
                  onRefresh: _refreshCurrent,
                  // 顶栏是浮层，留白放进列表自身的 padding，
                  // 这样它会随内容滚走，不会在顶部留下一条空白。
                  child: IndexedStack(
                    index: _index,
                    children: [
                      PostsListWidget(key: _postsKey, topInset: headerHeight),
                      CircleFeedWidget(key: _circleKey, topInset: headerHeight),
                      ActivityListWidget(
                        key: _activityKey,
                        topInset: headerHeight,
                      ),
                    ],
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
                          tabs: _tabLabels(),
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
      ),
    );
  }

  /// 品牌标识栏：左用户、中 logo、右常驻地点。
  ///
  /// 左右两栏等宽（随屏宽缩放），中间的 Expanded 就正好居中，
  /// 屏宽再窄 logo 也只是等比缩小，不会被挤没。
  Widget _buildBrandBar() {
    return SizedBox(
      height: _brandBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideSlot = (constraints.maxWidth * 0.28).clamp(76.0, 108.0);
          return Row(
            children: [
              SizedBox(
                width: sideSlot,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildUserChip(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: BrandMarkLottie(controller: _brandAnim, height: 40),
                  ),
                ),
              ),
              SizedBox(
                width: sideSlot,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildRegionChip(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserChip() {
    final colors = context.colors;
    final loggedIn = Supabase.instance.client.auth.currentUser != null;

    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: MyProfileStore.profile,
      builder: (context, profile, _) {
        final avatarUrl = loggedIn ? (profile?['avatar_url'] as String?) : null;
        final nickname = (profile?['nickname'] as String?)?.trim() ?? '';
        final name = loggedIn ? (nickname.isEmpty ? '雪友' : nickname) : '登录';

        return Semantics(
          button: true,
          label: loggedIn ? '$name 的主页' : '登录',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: loggedIn ? _openMyProfile : _openLogin,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAvatar(url: avatarUrl, size: 30),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 58),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
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
      },
    );
  }

  /// 常驻地点胶囊：图标 + 地区，点击可切换。
  Widget _buildRegionChip() {
    final colors = context.colors;
    final geo = GeoRepository.instance;

    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: MyProfileStore.profile,
      builder: (context, profile, _) {
        final region = (profile?['resident_region'] as String?)?.trim() ?? '';
        final resort = (profile?['resident_resort'] as String?)?.trim() ?? '';
        // 只显示最末一级行政区 + 雪场，例如「崇礼·富龙」，避免胶囊过长。
        final parts = <String>[
          if (region.isNotEmpty) region.split('·').last.trim(),
          if (resort.isNotEmpty && resort != geo.noFixedResort)
            shortResortName(resort),
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
                    width: 30,
                    height: 18,
                    child: SvgPicture.asset(
                      'assets/brand/icon_region.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        colors.muted,
                        BlendMode.srcIn,
                      ),
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
      },
    );
  }
}
