import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web 端刷新音效：直接用 HTMLAudioElement 播放内置 WAV。
///
/// 不走插件通道，避免 Web 上插件未注册导致的异常；
/// 因为播放由用户手势触发，不会被浏览器的自动播放策略拦截。
class RefreshSound {
  const RefreshSound._();

  static const String assetPath = 'assets/assets/sfx/refresh.wav';

  static web.HTMLAudioElement? _player;

  static String get _url => Uri.base.resolve(assetPath).toString();

  static void prepare() {
    if (_player != null) return;
    try {
      _player = web.HTMLAudioElement()
        ..src = _url
        ..preload = 'auto'
        ..volume = 0.55;
    } catch (_) {
      // 浏览器不支持时静默跳过。
    }
  }

  static Future<void> play() async {
    prepare();
    final player = _player;
    if (player == null) return;
    try {
      player.currentTime = 0;
      await player.play().toDart;
    } catch (_) {
      // 自动播放被拦截或解码失败时忽略。
    }
  }

  /// 震动反馈：Android Chrome 支持，iOS Safari 没有该 API（静默忽略）。
  static void vibrate(int milliseconds) {
    try {
      web.window.navigator.vibrate(milliseconds.toJS);
    } catch (_) {
      // 不支持震动时忽略。
    }
  }
}
