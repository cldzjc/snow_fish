import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_tabs.dart';
import 'activity_list_widget.dart';
import 'posts_list_widget.dart';

/// 首页当前是否停留在「约约约」，供底部发布入口判断默认发布类型。
final ValueNotifier<bool> homeActivityTabActive = ValueNotifier<bool>(false);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> _tabs = <String>['sk社区', '约约约'];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    homeActivityTabActive.value = _index == 1;
  }

  @override
  void dispose() {
    homeActivityTabActive.value = false;
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    homeActivityTabActive.value = index == 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  'skneo.',
                  style: AppText.brand.copyWith(color: colors.ink),
                ),
              ),
            ),
            AppTabs(tabs: _tabs, index: _index, onChanged: _select),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [PostsListWidget(), ActivityListWidget()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
