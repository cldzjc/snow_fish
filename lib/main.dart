import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'supabase_client.dart';
import 'config.dart';
import 'pages/home_tabs.dart';
import 'pages/post_detail_page.dart';
import 'services/deep_link.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme.dart';
import 'utils/url_strategy.dart' as url_strategy;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web 使用 /p/<id> 形式的真实路径，分享链接不带 `#`。
  url_strategy.configureUrlStrategy();

  if (!USE_LOCAL_DATA) {
    try {
      await SupabaseClientManager.initialize();
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialize error: $e');
      // 如果 Supabase 初始化失败，仍可继续运行本地模式
    }
  }

  // 分享链接里的帖子 id 必须在 Flutter 接管浏览器历史之前读出，
  // 否则地址会被规范化成 "/"。
  final sharedPostId = DeepLink.initialPostId;

  runApp(MyApp(initialPostId: sharedPostId));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialPostId});

  final String? initialPostId;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSharedLink());
  }

  /// 打开分享链接 https://skneo.club/p/<entity_id> 时直接进入帖子详情。
  void _openSharedLink() {
    final postId = widget.initialPostId;
    if (postId == null) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => PostDetailPage(postId: postId)),
    );
    // 把地址栏还原成分享链接，避免被规范化成 "/"。
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse('/p/$postId'),
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skneo · 雪鱼社区',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // 桌面/平板上把内容限制在移动端宽度，避免拉伸成另一种版式。
      builder: (context, child) {
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.pageMax),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: const HomeTabs(),
    );
  }
}
