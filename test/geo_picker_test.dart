import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_fish/constants/geo.dart';
import 'package:snow_fish/theme/app_theme.dart';
import 'package:snow_fish/widgets/app/geo_picker_sheet.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await GeoRepository.instance.load();
  });

  testWidgets('地区选择面板可按省 → 市 → 区县逐级推进', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GeoSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showGeoPicker(
                    context,
                    title: '常驻地区',
                    initialRegion: '河北·张家口·崇礼',
                    initialResort: '富龙',
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    // 左栏四级都在
    expect(find.text('省份'), findsOneWidget);
    expect(find.text('城市'), findsOneWidget);
    expect(find.text('区县'), findsOneWidget);
    expect(find.text('雪场'), findsOneWidget);

    // 已有值会带出来
    expect(find.text('崇礼'), findsWidgets);

    // 切到省份栏，列表里应该有 31 个省级行政区之一
    await tester.tap(find.text('省份'));
    await tester.pumpAndSettle();
    expect(find.text('河北'), findsWidgets);

    // 选河北后自动推进到城市列表
    await tester.tap(find.text('河北').last);
    await tester.pumpAndSettle();
    expect(find.text('张家口'), findsWidgets);

    // 一直选到雪场并确认
    await tester.tap(find.text('张家口').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('崇礼').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('富龙').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.region, '河北·张家口·崇礼');
    expect(result!.resort, '富龙');
  });

  test('雪场名会去掉「滑雪场」后缀', () {
    expect(shortResortName('万龙滑雪场'), '万龙');
    expect(shortResortName('云顶滑雪公园'), '云顶滑雪公园');
    expect(shortResortName('富龙'), '富龙');
  });
}
