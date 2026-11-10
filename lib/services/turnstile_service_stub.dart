class TurnstileService {
  bool get isSupported => false;

  Future<String?> getToken() async => null;

  Future<bool> verifyWithSupabase(String token) async => false;
}
