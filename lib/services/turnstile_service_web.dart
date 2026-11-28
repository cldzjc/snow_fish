import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@JS('skneoTurnstileRender')
external void _renderTurnstile(JSFunction callback);

@JS('skneoTurnstileExecute')
external void _executeTurnstile();

@JS('skneoTurnstileReset')
external void _resetTurnstile();

@JS('skneoTurnstileWhenVisible')
external void _whenVisible(JSFunction run);

@JS('skneoTurnstileLastError')
external JSString? _lastErrorCode();

/// 一次人机验证的结论。
enum TurnstileOutcome {
  /// 服务端确认通过，可以继续发验证码。
  verified,

  /// 服务端明确拒绝（token 已被用过、过期或伪造）。
  rejected,

  /// 连不上校验服务，属于网络问题，重新挑战没有意义。
  unavailable,
}

class TurnstileService {
  bool get isSupported => true;

  /// 等太久还没结果时置为 true，页面据此提示「如果出现验证框请点一下」。
  static final ValueNotifier<bool> challengeSlow = ValueNotifier<bool>(false);

  /// Turnstile token 有效期约 5 分钟，留一点余量。
  static const Duration _freshFor = Duration(minutes: 4);
  static const Duration _tokenTimeout = Duration(seconds: 40);
  static const Duration _slowAfter = Duration(seconds: 3);

  static String? _token;
  static DateTime? _tokenAt;
  static Future<String?>? _pending;
  static String? _lastFailure;

  /// 打开登录 / 注册页时调用：提前把 token 拿到手，点按钮时就不用等。
  Future<void> warmUp() async {
    await _ensureToken();
  }

  /// 取 token → 服务端校验，失败时换一个新 token 再试一次。
  Future<TurnstileOutcome> ensureVerified() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _ensureToken(forceNew: attempt > 0);
      // token 只能用一次，取走即作废；否则下次 execute() 会把旧 token 还回来。
      _token = null;
      _tokenAt = null;
      if (token == null) continue;
      switch (await _verify(token)) {
        case TurnstileOutcome.verified:
          return TurnstileOutcome.verified;
        case TurnstileOutcome.unavailable:
          return TurnstileOutcome.unavailable;
        case TurnstileOutcome.rejected:
          continue;
      }
    }
    return TurnstileOutcome.rejected;
  }

  /// 验证失败时的用户可读原因。
  String get failureMessage {
    if (_lastFailure == 'script') return '人机验证组件加载失败，请检查网络后重试';
    if (_lastFailure == 'expired') return '人机验证已过期，请再试一次';
    return '人机验证未完成，请再试一次';
  }

  bool get _isFresh {
    final at = _tokenAt;
    if (at == null || _token == null) return false;
    return DateTime.now().difference(at) < _freshFor;
  }

  /// 复用进行中的请求、复用未过期的 token，否则重新跑一次挑战。
  Future<String?> _ensureToken({bool forceNew = false}) {
    final pending = _pending;
    if (pending != null) return pending;
    if (!forceNew && _isFresh) return Future<String?>.value(_token);
    final future = _acquire(forceNew: forceNew);
    _pending = future;
    future.whenComplete(() {
      if (identical(_pending, future)) _pending = null;
    });
    return future;
  }

  Future<String?> _acquire({required bool forceNew}) async {
    if (forceNew) {
      _token = null;
      _tokenAt = null;
    }
    final completer = Completer<String?>();
    void finish(String? token) {
      if (completer.isCompleted) return;
      if (token == null || token.isEmpty) {
        completer.complete(null);
      } else {
        completer.complete(token);
      }
    }

    final callback = ((JSString token) => finish(token.toDart)).toJS;
    Timer? slowTimer;
    try {
      await _waitVisible();
      // 先 reset 再 execute：不带 reset 的 execute 会把上一次的 token 原样返回。
      _resetTurnstile();
      _renderTurnstile(callback);
      _executeTurnstile();
      slowTimer = Timer(_slowAfter, () => challengeSlow.value = true);
      final token = await completer.future.timeout(
        _tokenTimeout,
        onTimeout: () => null,
      );
      if (token == null || token.isEmpty) {
        _lastFailure = _lastErrorCode()?.toDart ?? 'timeout';
        return null;
      }
      _lastFailure = null;
      _token = token;
      _tokenAt = DateTime.now();
      return token;
    } catch (_) {
      _lastFailure = 'execute';
      return null;
    } finally {
      slowTimer?.cancel();
      challengeSlow.value = false;
    }
  }

  /// 挑战必须在可见页面上跑，否则 Turnstile 会反复报 300030。
  Future<void> _waitVisible() {
    final completer = Completer<void>();
    _whenVisible((() {
          if (!completer.isCompleted) completer.complete();
        }).toJS);
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  Future<TurnstileOutcome> _verify(String token) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-turnstile',
        body: {'token': token},
      );
      final data = response.data;
      return data is Map && data['success'] == true
          ? TurnstileOutcome.verified
          : TurnstileOutcome.rejected;
    } catch (error) {
      debugPrint('人机验证校验失败: $error');
      return TurnstileOutcome.unavailable;
    }
  }
}
