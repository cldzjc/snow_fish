import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 作者资料（昵称 / 头像 / 常驻地点）的共享缓存。
///
/// 卡片、详情页、开屏预取都读同一份，避免每个列表各自查一遍。
class ProfileCache {
  ProfileCache._();

  static final Map<String, Map<String, dynamic>> _rows =
      <String, Map<String, dynamic>>{};
  static final Set<String> _inFlight = <String>{};

  static Map<String, dynamic>? get(String userId) => _rows[userId];

  /// 补齐缺失的资料；[force] 为 true 时重新拉取已知用户。
  /// 返回本次是否真的发了请求。
  static Future<bool> ensure(
    Iterable<String> userIds, {
    bool force = false,
  }) async {
    final missing = userIds
        .where((id) => id.isNotEmpty)
        .where((id) => force || !_rows.containsKey(id))
        .where((id) => !_inFlight.contains(id))
        .toSet()
        .toList();
    if (missing.isEmpty) return false;

    _inFlight.addAll(missing);
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .inFilter('id', missing);
      for (final profile in response as List) {
        final map = Map<String, dynamic>.from(profile as Map);
        final id = map['id'] as String?;
        if (id != null) _rows[id] = map;
      }
      return true;
    } catch (error) {
      debugPrint('加载作者资料失败: $error');
      return false;
    } finally {
      _inFlight.removeAll(missing);
    }
  }

  static void invalidate(String userId) => _rows.remove(userId);

  static void clear() {
    _rows.clear();
    _inFlight.clear();
  }
}
