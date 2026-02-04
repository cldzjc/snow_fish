import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'publish_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _currentIndex = 0;

  // 四个页面
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initPages();

    // 监听认证状态变化，确保所有页面都能响应登录状态变化
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (mounted) {
        setState(() {
          _initPages(); // 重新创建页面，确保状态更新
        });
      }
    });
  }

  void _initPages() {
    _pages = [
      const HomePage(),
      const PublishPage(),
      const ChatPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // ← 根据 index 切换页面
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // ← 更新选中项
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "首页"),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: "发布",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "消息",
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
