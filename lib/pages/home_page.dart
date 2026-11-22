import 'package:flutter/material.dart';
import 'posts_list_widget.dart';
import 'login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'publish_hub_page.dart';
import 'activity_list_widget.dart';

/// 首页当前是否停留在「约约约」Tab，供底部发布入口判断默认发布类型。
final ValueNotifier<bool> homeActivityTabActive = ValueNotifier<bool>(false);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_syncActiveTab);
  }

  void _syncActiveTab() {
    homeActivityTabActive.value = _tabController.index == 1;
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncActiveTab);
    homeActivityTabActive.value = false;
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '雪鱼社区',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'sk社区'),
            Tab(text: '约约约'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [PostsListWidget(), ActivityListWidget()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '发布动态',
        onPressed: () async {
          if (Supabase.instance.client.auth.currentSession == null) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
            if (!context.mounted ||
                Supabase.instance.client.auth.currentSession == null) {
              return;
            }
          }
          final published = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PublishHubPage(defaultActivity: _tabController.index == 1),
            ),
          );
          if (published == true && context.mounted) {
            feedRefreshTick.value++;
            activityRefreshTick.value++;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('动态发布成功')));
          }
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}
