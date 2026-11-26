import 'package:flutter_test/flutter_test.dart';
import 'package:snow_fish/models/circle.dart';
import 'package:snow_fish/services/circle_repository.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await CircleRepository.instance.load();
  });

  test('区县圈由 geo.json 派生，并包含旗下雪场圈', () {
    final repo = CircleRepository.instance;
    final chongli = repo.byId('河北·张家口·崇礼');
    expect(chongli, isNotNull);
    expect(chongli!.label, '崇礼圈');

    final scope = repo.scopeIds(chongli);
    expect(scope.first, '河北·张家口·崇礼');
    expect(scope, contains('河北·张家口·崇礼/富龙'));
    expect(scope.length, greaterThan(1));

    final fulong = repo.byId('河北·张家口·崇礼/富龙');
    expect(fulong, isNotNull);
    expect(fulong!.label, '富龙圈');
    expect(fulong.isResortCircle, isTrue);
    // 雪场圈只看自己，不带区县圈。
    expect(repo.scopeIds(fulong), <String>['河北·张家口·崇礼/富龙']);
  });

  test('按地区 + 雪场定位圈子，雪场为空时回落到区县圈', () {
    final repo = CircleRepository.instance;
    expect(repo.forSelection('河北·张家口·崇礼', '富龙')?.id, '河北·张家口·崇礼/富龙');
    expect(repo.forSelection('河北·张家口·崇礼', '')?.id, '河北·张家口·崇礼');
    expect(repo.forSelection('河北·张家口·崇礼', '暂无固定雪场')?.id, '河北·张家口·崇礼');
    expect(repo.forSelection('不存在的地区', ''), isNull);
  });

  test('入圈信息能还原成区县圈 + 雪场圈', () {
    final membership = CircleRepository.instance.membershipFrom(
      region: '河北·张家口·崇礼',
      resort: '富龙',
    );
    expect(membership, isNotNull);
    expect(membership!.district.label, '崇礼圈');
    expect(membership.resort!.label, '富龙圈');
    expect(membership.primary.id, '河北·张家口·崇礼/富龙');
  });

  test('帖子上的 circle_id 能转成卡片标签', () {
    final repo = CircleRepository.instance;
    expect(repo.tagFor('河北·张家口·崇礼/富龙'), '富龙圈');
    expect(repo.tagFor('河北·张家口·崇礼'), '崇礼圈');
    expect(repo.tagFor(null), isNull);
  });

  group('30 天换圈锁定', () {
    final now = DateTime(2026, 11, 26, 12);

    CircleMembership membership({DateTime? lockedUntil}) {
      return CircleRepository.instance.membershipFrom(
        region: '河北·张家口·崇礼',
        resort: '富龙',
        joinedAt: now,
        lockedUntil: lockedUntil,
      )!;
    }

    test('锁定期内不可换圈，剩余天数向上取整', () {
      final m = membership(lockedUntil: now.add(const Duration(days: 12)));
      expect(m.isLockedAt(now), isTrue);
      expect(m.remainingLockDaysAt(now), 12);
    });

    test('不足一天也算一天', () {
      final m = membership(lockedUntil: now.add(const Duration(hours: 3)));
      expect(m.remainingLockDaysAt(now), 1);
    });

    test('到期后可以换圈', () {
      final m = membership(lockedUntil: now.subtract(const Duration(days: 1)));
      expect(m.isLockedAt(now), isFalse);
      expect(m.remainingLockDaysAt(now), 0);
    });

    test('没有锁定时间时不限制', () {
      final m = membership();
      expect(m.isLockedAt(now), isFalse);
      expect(m.remainingLockDaysAt(now), 0);
    });
  });
}
