/// 非 Web 平台的人机验证占位实现。
///
/// 移动端 / 桌面端没有 Turnstile，直接视为通过。
enum TurnstileOutcome { verified, skipped, rejected }

class TurnstileService {
  bool get isSupported => false;

  Future<void> warmUp() async {}

  Future<TurnstileOutcome> ensureVerified() async => TurnstileOutcome.verified;
}
