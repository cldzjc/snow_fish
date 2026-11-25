import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'refresh_sound.dart';

/// 下拉刷新的触感与音效反馈。
///
/// - Web：震动走 `navigator.vibrate`（Android Chrome 有效，iOS Safari 无此 API），
///   音效走 HTMLAudioElement。
/// - Android / iOS 原生：走系统 HapticFeedback。
class RefreshFeedback {
  RefreshFeedback._();

  static final RefreshFeedback instance = RefreshFeedback._();

  void prepare() => RefreshSound.prepare();

  /// 手指移动时的轻微刻度感。
  void tick() {
    if (kIsWeb) {
      RefreshSound.vibrate(6);
      return;
    }
    _haptic(HapticFeedback.selectionClick);
  }

  /// 刚好越过刷新阈值。
  void armed() {
    if (kIsWeb) {
      RefreshSound.vibrate(14);
    } else {
      _haptic(HapticFeedback.lightImpact);
    }
    RefreshSound.play();
  }

  /// 真正触发刷新。
  void trigger() {
    if (kIsWeb) {
      RefreshSound.vibrate(22);
      return;
    }
    _haptic(HapticFeedback.mediumImpact);
  }

  void _haptic(Future<void> Function() action) {
    try {
      action();
    } catch (_) {
      // 设备不支持触感时忽略。
    }
  }
}
