import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_fish/models/circle.dart';
import 'package:snow_fish/pages/circle_settings_page.dart';
import 'package:snow_fish/services/circle_repository.dart';
import 'package:snow_fish/services/my_profile_store.dart';
import 'package:snow_fish/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await CircleRepository.instance.load();
  });

  tearDown(() => MyProfileStore.profile.value = null);

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const CircleSettingsPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未入圈时显示入圈入口，不显示换圈', (tester) async {
    MyProfileStore.profile.value = {'id': 'u1', 'nickname': '雪友'};
    await pumpSettings(tester);

    expect(find.text('还没有入圈。选一个城市或雪场，只看同圈雪友的分享。'), findsOneWidget);
    expect(find.text('入圈'), findsOneWidget);
    expect(find.text('换一个圈'), findsNothing);
  });

  testWidgets('锁定期内换圈按钮不可用并显示剩余天数', (tester) async {
    final now = DateTime.now();
    MyProfileStore.profile.value = {
      'id': 'u1',
      'nickname': '雪友',
      'circle_region': '河北·张家口·崇礼',
      'circle_resort': '富龙',
      'circle_joined_at': now
          .subtract(const Duration(days: 10))
          .toUtc()
          .toIso8601String(),
      'circle_locked_until': now
          .add(const Duration(days: 20))
          .toUtc()
          .toIso8601String(),
    };
    await pumpSettings(tester);

    expect(find.text('崇礼圈'), findsWidgets);
    expect(find.text('富龙圈'), findsWidgets);
    expect(find.text('还需 20 天才能换圈'), findsOneWidget);

    final button = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('还需 20 天才能换圈'),
        matching: find.byType(InkWell),
      ),
    );
    expect(button.onTap, isNull);
  });

  testWidgets('锁定到期后可以换圈', (tester) async {
    final now = DateTime.now();
    MyProfileStore.profile.value = {
      'id': 'u1',
      'nickname': '雪友',
      'circle_region': '河北·张家口·崇礼',
      'circle_resort': '富龙',
      'circle_joined_at': now
          .subtract(const Duration(days: 40))
          .toUtc()
          .toIso8601String(),
      'circle_locked_until': now
          .subtract(const Duration(days: 10))
          .toUtc()
          .toIso8601String(),
    };
    await pumpSettings(tester);

    expect(find.text('换一个圈'), findsOneWidget);
    expect(find.text('锁定期已结束，可以换圈'), findsOneWidget);
  });

  test('入圈时间文案包含锁定到期日', () {
    final membership = CircleMembership(
      district: CircleRepository.instance.byId('河北·张家口·崇礼')!,
      joinedAt: DateTime(2026, 11, 26),
      lockedUntil: DateTime(2026, 12, 26),
    );
    expect(openedAtLabel(membership), '入圈于 2026-11-26 · 锁定至 2026-12-26');
  });
}
