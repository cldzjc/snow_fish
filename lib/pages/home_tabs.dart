import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_spacing.dart';
import '../widgets/app/app_bottom_nav.dart';
import '../widgets/app/immersive.dart';
import 'activity_list_widget.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'message_placeholder_page.dart';
import 'notifications_page.dart';
import 'posts_list_widget.dart';
import 'profile_page.dart';
import 'publish_hub_page.dart';

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  /// IndexedStack 下标：0 首页 / 1 私信 / 2 通知 / 3 我的。
  /// 「发布」不占栈位，是动作。
  int _stackIndex = 0;
  late final StreamSubscription<AuthState> _authSubscription;

  /// 栈下标 → 底部导航槽位。
  static const List<int> _navSlots = <int>[0, 1, 3, 4];

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _openPublish() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentSession == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录后才能发布')));
        return;
      }
    }
    if (!mounted) return;
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PublishHubPage(defaultActivity: homeActivityTabActive.value),
      ),
    );
    if (published == true) {
      feedRefreshTick.value++;
      activityRefreshTick.value++;
    }
  }

  void _onSelect(int slot) {
    if (slot == 2) {
      _openPublish();
      return;
    }
    final next = _navSlots.indexOf(slot);
    if (next < 0 || next == _stackIndex) return;
    revealChrome();
    setState(() => _stackIndex = next);
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final pages = <Widget>[
      const HomePage(),
      const MessagePlaceholderPage(),
      NotificationsPage(key: ValueKey('notif-${userId ?? 'guest'}')),
      ProfilePage(key: ValueKey('me-${userId ?? 'guest'}'), userId: userId),
    ];

    return Scaffold(
      body: IndexedStack(index: _stackIndex, children: pages),
      bottomNavigationBar: ImmersiveHide(
        hideOffset: const Offset(0, 96),
        child: ValueListenableBuilder<int>(
          valueListenable: notificationUnreadCount,
          builder: (context, unread, _) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: AppBottomNav(
                selected: _navSlots[_stackIndex],
                onSelect: _onSelect,
                unread: unread,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
