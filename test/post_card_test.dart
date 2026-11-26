import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_fish/models/base_entity.dart';
import 'package:snow_fish/theme/app_theme.dart';
import 'package:snow_fish/widgets/post_card.dart';

BaseEntity _post({Map<String, dynamic> extraData = const {}}) {
  return BaseEntity(
    id: 'p1',
    userId: 'u1',
    entityType: 'post',
    title: '第一次去崇礼滑雪',
    content: '需要准备什么？',
    createdAt: DateTime.now(),
    extraData: extraData,
  );
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('帖子卡片右上角展示发布地点的区县·雪场', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PostCard(
          post: _post(
            extraData: {'region_id': '河北·张家口·崇礼区', 'resort_id': '富龙滑雪场'},
          ),
          authorName: '爱滑雪的小老鼠',
        ),
      ),
    );

    expect(find.text('崇礼区·富龙'), findsOneWidget);
  });

  testWidgets('老帖子没有发布地点时回退到作者常驻地区', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PostCard(
          post: _post(),
          authorName: 'zch',
          region: '北京·北京市·延庆区',
          resort: '云顶滑雪场',
        ),
      ),
    );

    expect(find.text('延庆区·云顶'), findsOneWidget);
  });

  testWidgets('标题与正文都会展示，不做简化行', (tester) async {
    await tester.pumpWidget(_wrap(PostCard(post: _post(), authorName: 'zch')));

    expect(find.text('第一次去崇礼滑雪'), findsOneWidget);
    expect(find.text('需要准备什么？'), findsOneWidget);
  });
}
