import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import 'circle_repository.dart';

/// 当前登录用户的资料缓存。
///
/// 首页顶栏、我的页、帖子卡片的作者标签都读这一份，
/// 修改地区/雪场后广播一次，所有地方立刻同步，不用各自重新请求。
class MyProfileStore {
  MyProfileStore._();

  /// 当前用户资料；未登录或未加载时为 null。
  static final ValueNotifier<Map<String, dynamic>?> profile =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// 资料变更计数，供需要感知变化的页面监听。
  static final ValueNotifier<int> changedTick = ValueNotifier<int>(0);

  static String? get userId => Supabase.instance.client.auth.currentUser?.id;

  static Map<String, dynamic>? get value => profile.value;

  /// 登录态兜底：先给出昵称/头像，避免界面空一屏。
  static void seedFromAuth() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      profile.value = null;
      return;
    }
    profile.value = <String, dynamic>{
      ...?profile.value,
      'id': user.id,
      'nickname': user.userMetadata?['nickname'] ?? '',
      'avatar_url': user.userMetadata?['avatar_url'] ?? '',
    };
  }

  /// 读取线上资料（force=false 时已有数据也照样刷新）。
  static Future<void> load() async {
    final id = userId;
    if (id == null) {
      profile.value = null;
      return;
    }
    seedFromAuth();
    try {
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return;
      profile.value = Map<String, dynamic>.from(row);
    } catch (_) {
      // 读取失败时保留兜底值。
    }
  }

  /// 本地先更新，再写回数据库；失败时抛出，由调用方提示。
  static Future<void> updateLocation({
    required String region,
    required String resort,
  }) async {
    final id = userId;
    profile.value = <String, dynamic>{
      ...?profile.value,
      'resident_region': region,
      'resident_resort': resort,
    };
    changedTick.value++;
    if (id == null) return;
    await Supabase.instance.client
        .from('user_profiles')
        .update({'resident_region': region, 'resident_resort': resort})
        .eq('id', id);
    await load();
    changedTick.value++;
  }

  static void clear() {
    profile.value = null;
    changedTick.value++;
  }

  // ============ 圈子 ============
  //
  // 圈子和「常驻地点」是两套独立的数据：
  // 常驻地点可以随时改，圈子入圈后应当稳定，所以用 circle_region / circle_resort 单独存。

  /// 我没有入圈时为 null。
  static CircleMembership? get circle {
    final data = profile.value;
    if (data == null) return null;
    final region = (data['circle_region'] as String?)?.trim() ?? '';
    if (region.isEmpty) return null;
    final resort = (data['circle_resort'] as String?)?.trim() ?? '';
    final joinedRaw = (data['circle_joined_at'] as String?)?.trim() ?? '';
    final lockedRaw = (data['circle_locked_until'] as String?)?.trim() ?? '';
    return CircleRepository.instance.membershipFrom(
      region: region,
      resort: resort,
      joinedAt: joinedRaw.isEmpty
          ? null
          : DateTime.tryParse(joinedRaw)?.toLocal(),
      lockedUntil: lockedRaw.isEmpty
          ? null
          : DateTime.tryParse(lockedRaw)?.toLocal(),
    );
  }

  /// 入圈 / 换圈。
  ///
  /// 30 天锁定由数据库触发器强制，这里先写库再更新本地缓存，
  /// 写库失败（还在锁定期）时界面状态不会被污染。
  static Future<void> joinCircle({
    required String region,
    required String resort,
  }) async {
    final id = userId;
    if (id == null) return;
    await Supabase.instance.client
        .from('user_profiles')
        .update({'circle_region': region, 'circle_resort': resort})
        .eq('id', id);
    await load();
    changedTick.value++;
  }
}
