import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config.dart';
import 'pages/home_tabs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = false;
  String? firebaseInitError;
  if (USE_LOCAL_DATA) {
    // 使用本地数据时跳过 Firebase 初始化
    firebaseReady = true;
    firebaseInitError = null;
    debugPrint('USE_LOCAL_DATA=true: skipping Firebase.initializeApp()');
  } else {
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (e) {
      // 记录初始化错误，传递给应用以便进一步排查
      debugPrint('Firebase initialize error: $e');
      firebaseInitError = e.toString();
      firebaseReady = false;
    }
  }
  runApp(
    MyApp(isFirebaseReady: firebaseReady, firebaseInitError: firebaseInitError),
  );
}

class MyApp extends StatelessWidget {
  final bool isFirebaseReady;
  final String? firebaseInitError;
  const MyApp({
    super.key,
    required this.isFirebaseReady,
    this.firebaseInitError,
  });

  @override
  Widget build(BuildContext context) {
    // 如果有初始化错误，会在控制台打印（方便排查）
    if (firebaseInitError != null) {
      debugPrint('Firebase init error forwarded to MyApp: $firebaseInitError');
    }
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
      // 使用底部标签页容器作为首页，这样可以切换“首页 / 发布 / 消息 / 我的”
      home: HomeTabs(isFirebaseReady: isFirebaseReady),
    );
  }
}
