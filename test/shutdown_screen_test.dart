import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_fish/theme/app_theme.dart';
import 'package:snow_fish/widgets/app/shutdown_screen.dart';

void main() {
  testWidgets('关停时只显示一行提示文字，普通访客看不到解除入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ShutdownScreen(message: '一双无形的大手关闭了 skneo —— 大手子'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一双无形的大手关闭了 skneo —— 大手子'), findsOneWidget);
    // 测试环境没有登录态，解除入口不应出现。
    expect(find.text('解除关停'), findsNothing);
  });
}
