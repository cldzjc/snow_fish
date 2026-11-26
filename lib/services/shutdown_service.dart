import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../supabase_client.dart';

/// 全站关停开关。
///
/// 管理员在「内容治理中心 → 紧急操作」里打开后，所有客户端（含已经打开的页面）
/// 都会在白屏提示页停下。状态存在数据库，任何人打开页面都会先读一次，
/// 之后每 30 秒再确认一次。
class ShutdownService {
  ShutdownService._();

  static const Duration pollInterval = Duration(seconds: 30);

  static const String defaultMessage = '一双无形的大手关闭了 skneo —— 大手子';

  /// 为 null 表示正常运行；非 null 是关停时展示的说明文字。
  static final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  static Timer? _timer;
  static bool _started = false;

  /// 启动轮询。Supabase 未初始化（本地模式）时什么都不做。
  static void start() {
    if (_started || USE_LOCAL_DATA) return;
    _started = true;
    unawaited(refresh());
    _timer = Timer.periodic(pollInterval, (_) => refresh());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// 读一次开关状态；失败时保持当前状态，不误关也不误开。
  static Future<void> refresh() async {
    if (USE_LOCAL_DATA) return;
    try {
      final state = await load();
      if (state == null) return;
      message.value = state.closed
          ? (state.text.isEmpty ? defaultMessage : state.text)
          : null;
    } catch (error) {
      debugPrint('读取关停开关失败: $error');
    }
  }

  /// 读取当前关停配置；读不到时返回 null。
  static Future<({bool closed, String text})?> load() async {
    if (USE_LOCAL_DATA) return null;
    try {
      final row = await SupabaseClientManager.instance
          .from('app_settings')
          .select('closed, closed_message')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return null;
      return (
        closed: row['closed'] == true,
        text: (row['closed_message'] as String?)?.trim() ?? '',
      );
    } catch (error) {
      debugPrint('读取关停开关失败: $error');
      return null;
    }
  }

  /// 管理员切换关停状态。
  static Future<void> setClosed({
    required bool closed,
    required String text,
    required String userId,
  }) async {
    final value = text.trim().isEmpty ? defaultMessage : text.trim();
    await SupabaseClientManager.instance
        .from('app_settings')
        .update({
          'closed': closed,
          'closed_message': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': userId,
        })
        .eq('id', 1);
    message.value = closed ? value : null;
  }
}
