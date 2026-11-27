import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 手机号存放在私有表 user_contacts 里，不随用户资料公开返回。
///
/// 只在「参加/发起活动」需要双方联系时使用，个人主页不展示。
class ContactService {
  ContactService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 当前用户手机号（null 表示还没填）。
  static final ValueNotifier<String?> myPhone = ValueNotifier<String?>(null);

  static bool _loaded = false;
  static String? _loadedFor;

  /// 已缓存过就直接返回，[force] 用于改号后刷新。
  Future<String?> loadMine({bool force = false}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      myPhone.value = null;
      _loaded = false;
      _loadedFor = null;
      return null;
    }
    if (!force && _loaded && _loadedFor == uid) return myPhone.value;
    try {
      final result = await _client.rpc('my_phone');
      myPhone.value = result is String && result.trim().isNotEmpty
          ? result.trim()
          : null;
    } catch (_) {
      myPhone.value = null;
    }
    _loaded = true;
    _loadedFor = uid;
    return myPhone.value;
  }

  Future<String> save(String phone) async {
    final result = await _client.rpc(
      'set_my_phone',
      params: {'p_phone': phone},
    );
    final value = result is String ? result : phone;
    myPhone.value = value;
    _loaded = true;
    _loadedFor = _client.auth.currentUser?.id;
    return value;
  }

  /// 打码展示，例如 138****8000。
  static String mask(String phone) {
    final value = phone.trim();
    if (value.length < 7) return value;
    return '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
  }
}
