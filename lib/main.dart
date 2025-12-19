import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'config.dart';
import 'pages/home_tabs.dart';

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
      title: 'Ski Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      // 使用底部标签页容器作为首页
      home: const HomeTabs(),
    );
  }
}
