import 'package:flutter/material.dart';

import '../widgets/app/app_tabs.dart';
import '../widgets/app/brand_mark.dart';
import '../widgets/app/lottie_pull_refresh.dart';
import 'activity_list_widget.dart';
import 'posts_list_widget.dart';

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

  @override
  void initState() {
    super.initState();
    homeActivityTabActive.value = _index == 1;
  }

  @override
  void dispose() {
    homeActivityTabActive.value = false;
    _brandAnim.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    homeActivityTabActive.value = index == 1;
  }

  /// 刷新当前板块的数据，等真实请求结束再收起指示器。
  Future<void> _refreshCurrent() {
    final future = _index == 1
        ? _activityKey.currentState?.refreshNow()
        : _postsKey.currentState?.refreshNow();
    return future ?? Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Center(
                child: BrandMarkLottie(controller: _brandAnim, height: 30),
              ),
            ),
            Expanded(
              child: LottiePullRefresh(
                controller: _brandAnim,
                onRefresh: _refreshCurrent,
                child: Column(
                  children: [
                    AppTabs(tabs: _tabs, index: _index, onChanged: _select),
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
}
