import 'dart:async';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS('skneoTurnstileRender')
external void _renderTurnstile(JSFunction callback);

@JS('skneoTurnstileExecute')
external void _executeTurnstile();

@JS('skneoTurnstileReset')
external void _resetTurnstile();

class TurnstileService {
  bool get isSupported => true;

  Future<String?> getToken() async {
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
