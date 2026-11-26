import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import '../models/refresh_result.dart';
import '../services/circle_repository.dart';
import '../services/my_profile_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_icons.dart';
import 'circle_settings_page.dart';
import 'login_page.dart';
import 'posts_list_widget.dart';

/// 当前浏览的圈子，供「发布」判断要发到哪个圈。
///
/// 圈子设置页切换浏览范围时也改它，所以所有页面看到的是同一个值。
final ValueNotifier<Circle?> activeCircleForPublish = ValueNotifier<Circle?>(
  null,
);

/// 「?圈」板块：未入圈时给入圈入口，入圈后展示当前浏览圈子的信息流。
class CircleFeedWidget extends StatefulWidget {
  const CircleFeedWidget({super.key, this.topInset = 0});

  final double topInset;

  @override
  State<CircleFeedWidget> createState() => CircleFeedWidgetState();
}

class CircleFeedWidgetState extends State<CircleFeedWidget> {
  final GlobalKey<PostsListWidgetState> _feedKey =
      GlobalKey<PostsListWidgetState>();

  @override
  void initState() {
    super.initState();
    MyProfileStore.changedTick.addListener(_syncActive);
    _syncActive();
  }

  @override
  void dispose() {
    MyProfileStore.changedTick.removeListener(_syncActive);
    super.dispose();
  }

  /// 入圈信息变化时，把浏览范围收敛到合法的圈子。
  void _syncActive() {
    if (!mounted) return;
    final membership = MyProfileStore.circle;
    if (membership == null) {
      activeCircleForPublish.value = null;
      setState(() {});
      return;
    }
    final current = activeCircleForPublish.value;
    final valid =
        current != null &&
        (current.id == membership.district.id ||
            current.id == membership.resort?.id);
    if (!valid) activeCircleForPublish.value = membership.district;
    setState(() {});
  }

  /// 下拉刷新当前圈子；未入圈时不刷新。
  Future<RefreshResult?> refreshNow() async {
    if (MyProfileStore.circle == null) return null;
    return _feedKey.currentState?.refreshNow();
  }

  Future<void> _openSettings() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted || Supabase.instance.client.auth.currentUser == null) return;
      await MyProfileStore.load();
      if (!mounted) return;
      _syncActive();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CircleSettingsPage()),
    );
    if (mounted) _syncActive();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    final membership = MyProfileStore.circle;

    if (membership == null) {
      return _buildEmptyState(loggedIn: loggedIn);
    }

    final active = activeCircleForPublish.value ?? membership.district;
    final scope = CircleRepository.instance.scopeIds(active);

    return Column(
      children: [
        SizedBox(height: widget.topInset),
        CircleHeaderBar(onOpenSettings: _openSettings),
        Divider(height: 1, color: context.colors.line),
        Expanded(
          child: PostsListWidget(key: _feedKey, circleIds: scope),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required bool loggedIn}) {
    final colors = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpace.xl,
        widget.topInset + AppSpace.xxxl,
        AppSpace.xl,
        AppSpace.xxxl,
      ),
      children: [
        Icon(AppIcons.mountain, size: 40, color: colors.muted),
        const SizedBox(height: AppSpace.lg),
        Text(
          loggedIn ? '你还没有进圈' : '登录后可以进圈',
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(color: colors.ink),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          loggedIn ? '选一个城市或雪场，只看同圈雪友的分享。' : '圈子按城市和雪场划分，进圈后可以看到同圈的帖子。',
          textAlign: TextAlign.center,
          style: AppText.bodySmall.copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpace.xl),
        Center(
          child: AppButton(
            label: loggedIn ? '入圈' : '登录',
            onPressed: _openSettings,
          ),
        ),
      ],
    );
  }
}
