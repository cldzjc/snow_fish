import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'supabase_client.dart';
import 'config.dart';
import 'constants/geo.dart';
import 'pages/home_tabs.dart';
import 'pages/post_detail_page.dart';
import 'services/circle_repository.dart';
import 'services/deep_link.dart';
import 'services/entity_service.dart';
import 'services/shutdown_service.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme.dart';
import 'utils/url_strategy.dart' as url_strategy;
import 'widgets/app/shutdown_screen.dart';
import 'widgets/app/splash_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web 使用 /p/<id> 形式的真实路径，分享链接不带 `#`。
  url_strategy.configureUrlStrategy();

  // 地区数据先读内置文件，再由站点上的同名文件覆盖（改文件即可热更新）。
  await GeoRepository.instance.load();
  await CircleRepository.instance.load();
  unawaited(GeoRepository.instance.refreshFromRemote());
  unawaited(CircleRepository.instance.refreshFromRemote());

  if (!USE_LOCAL_DATA) {
    try {
      await SupabaseClientManager.initialize();
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialize error: $e');
      // 如果 Supabase 初始化失败，仍可继续运行本地模式
    }
  }

  // 分享链接里的短码必须在 Flutter 接管浏览器历史之前读出，
  // 否则地址会被规范化成 "/"。
  final sharedPostKey = DeepLink.initialPostKey;

  // 全站关停开关：启动时读一次，之后每 30 秒确认一次。
  ShutdownService.start();

  runApp(MyApp(initialPostKey: sharedPostKey));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialPostKey});

  /// 分享链接里的帖子短码或完整 uuid。
  final String? initialPostKey;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final EntityService _entityService = EntityService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSharedLink());
  }

  /// 打开分享链接 https://skneo.club/<短码> 时直接进入帖子详情。
  Future<void> _openSharedLink() async {
    final key = widget.initialPostKey;
    if (key == null) return;
    var entityId = DeepLink.asFullUuid(key);
    entityId ??= await _entityService.resolveEntityIdByShortCode(key);
    if (!mounted) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    if (entityId == null) {
      // 内容已删除或被隐藏：留在首页并给出提示。
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('这条内容已经不存在了')),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(postId: entityId!),
      ),
    );
    // 把地址栏还原成分享链接，避免被规范化成 "/"。
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse('/$key'),
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skneo · 雪鱼社区',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
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
      home: ValueListenableBuilder<String?>(
        valueListenable: ShutdownService.message,
        builder: (context, closedMessage, _) {
          if (closedMessage != null) {
            return ShutdownScreen(message: closedMessage);
          }
          return const SplashGate(child: HomeTabs());
        },
      ),
    );
  }
}
