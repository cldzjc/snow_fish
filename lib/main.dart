import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'config.dart';
import 'pages/home_tabs.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!USE_LOCAL_DATA) {
    try {
      await SupabaseClientManager.initialize();
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialize error: $e');
      // 如果 Supabase 初始化失败，仍可继续运行本地模式
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skneo · 雪鱼社区',
      debugShowCheckedModeBanner: false,
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
