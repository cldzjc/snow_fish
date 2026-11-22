import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'message_placeholder_page.dart';
import 'notifications_page.dart';
import 'publish_hub_page.dart';
import 'login_page.dart';
import 'posts_list_widget.dart';
import 'activity_list_widget.dart';

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _currentIndex = 0;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _openPublish(BuildContext context) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!context.mounted) return;
      if (Supabase.instance.client.auth.currentSession == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录后才能发布')));
        return;
      }
    }
    if (!context.mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final pages = <Widget>[
      const HomePage(),
      const MessagePlaceholderPage(),
      const SizedBox.shrink(),
      NotificationsPage(key: ValueKey(userId ?? 'logged-out')),
      ProfilePage(key: ValueKey(userId ?? 'logged-out'), userId: userId),
    ];

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 2) {
            _openPublish(context);
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "首页"),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "私信",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "发布",
          ),
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: notificationUnreadCount,
              builder: (_, count, __) => Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none),
                  if (count > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            label: "通知",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "我的",
          ),
        ],
      ),
    );
  }
}
