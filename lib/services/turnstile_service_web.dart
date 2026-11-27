import 'dart:async';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS('skneoTurnstileRender')
external void _renderTurnstile(JSFunction callback);

@JS('skneoTurnstileExecute')
external void _executeTurnstile();

@JS('skneoTurnstileReset')
external void _resetTurnstile();

@JS('skneoTurnstileWarmUp')
external void _warmUpTurnstile(JSFunction callback);

class TurnstileService {
  bool get isSupported => true;

  static String? _cachedToken;
  static DateTime? _cachedAt;

  /// 提前跑一次验证，把 token 先拿到手，减少点按钮后的等待。
  Future<void> warmUp() async {
    if (!isSupported || _isFresh || _warmUpStarted) return;
    _warmUpStarted = true;
    final completer = Completer<String?>();
    void finish(String? token) {
      if (!completer.isCompleted) completer.complete(token);
    }

    final callback = ((JSString token) => finish(token.toDart)).toJS;
    try {
      _warmUpTurnstile(callback);
      final token = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        _cachedAt = DateTime.now();
      }
      _resetTurnstile();
    } catch (_) {
      _resetTurnstile();
    }
  }

  static bool _warmUpStarted = false;

  Future<String?> getToken() async {
    if (_isFresh) {
      final token = _cachedToken;
      _cachedToken = null;
      _cachedAt = null;
      return token;
    }
    return _request();
  }

  /// Turnstile token 有效期约 5 分钟，留一点余量。
  bool get _isFresh {
    final at = _cachedAt;
    if (at == null || _cachedToken == null) return false;
    return DateTime.now().difference(at) < const Duration(minutes: 4);
  }

  Future<String?> _request() async {
    final completer = Completer<String?>();
    var completed = false;

    void finish(String? token) {
      if (completed) return;
      completed = true;
      if (token == null || token.isEmpty) {
        completer.complete(null);
      } else {
        completer.complete(token);
      }
    }

    final callback = ((JSString token) => finish(token.toDart)).toJS;
    try {
      _renderTurnstile(callback);
      _executeTurnstile();
      final token = await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => null,
      );
      _resetTurnstile();
      return token;
    } catch (_) {
      _resetTurnstile();
      return null;
    }
  }

  Future<bool> verifyWithSupabase(String token) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-turnstile',
        body: {'token': token},
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
