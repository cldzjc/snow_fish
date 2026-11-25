/// 非 Web 平台：不使用内置音效（依赖系统触感反馈即可）。
class RefreshSound {
  const RefreshSound._();

  static void prepare() {}

  static Future<void> play() async {}

  static void vibrate(int milliseconds) {}
}
