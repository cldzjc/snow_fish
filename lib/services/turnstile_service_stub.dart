class TurnstileService {
  bool get isSupported => false;

  Future<void> warmUp() async {}

  Future<String?> getToken() async => null;

  Future<bool> verifyWithSupabase(String token) async => false;
}
