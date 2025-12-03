import 'package:flutter/material.dart';
import 'home_page.dart';
import 'publish_page.dart'; // 如无此文件，请根据你的项目调整或创建
import 'chat_page.dart'; // 如无此文件，请根据你的项目调整或创建
import 'profile_page.dart'; // 如无此文件，请根据你的项目调整或创建

class HomeTabs extends StatefulWidget {
  final bool isFirebaseReady;
  const HomeTabs({super.key, required this.isFirebaseReady});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _currentIndex = 0;

  // 四个页面
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 传递初始化状态给需要数据库的页面
    _pages = [
      HomePage(isFirebaseReady: widget.isFirebaseReady),
      PublishPage(isFirebaseReady: widget.isFirebaseReady),
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
