import 'package:flutter/foundation.dart';

/// 非 Web 平台的人机验证占位实现。
///
/// 移动端 WebView / 桌面端没有 Turnstile，直接视为通过。
enum TurnstileOutcome { verified, rejected, unavailable }

class TurnstileService {
  bool get isSupported => false;

  static final ValueNotifier<bool> challengeSlow = ValueNotifier<bool>(false);

  Future<void> warmUp() async {}

  Future<TurnstileOutcome> ensureVerified() async => TurnstileOutcome.verified;

  String get failureMessage => '人机验证未完成，请再试一次';
}
