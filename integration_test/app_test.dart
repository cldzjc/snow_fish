import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:snow_fish/main.dart';
import 'package:snow_fish/supabase_client.dart';
import 'package:snow_fish/config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!USE_LOCAL_DATA) {
      await SupabaseClientManager.initialize();
      print('Supabase initialized in integration test');
    }
  });

  group('Supabase Integration Tests', () {
    testWidgets('Supabase Core Initialization', (tester) async {
      if (USE_LOCAL_DATA) return;
      // 验证 Supabase 客户端已初始化
      expect(SupabaseClientManager.instance, isNotNull);
      print('Supabase initialized successfully');
    });

    testWidgets('Full App Startup', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 验证应用主要组件存在
      expect(find.byType(MaterialApp), findsOneWidget);
      print('Full app initialized successfully');
    });
  });
}
