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
  /// 服务端确认通过。
  verified,

  /// 挑战在预算内没跑出来（网络不通、iframe 跨域通信失败等）。
  ///
  /// 这种情况放行：校验目前在客户端，绕过它的成本本来就低，
  /// 为了一个拿不到的 token 把真人挡在门外不值当。
  /// 真正的防刷交给 Supabase Auth 的频率限制和 Cloudflare 的 WAF 限流。
  skipped,

  /// 拿到了 token，但服务端明确说无效。
  rejected,
}

class TurnstileService {
  bool get isSupported => true;

  /// token 有效期约 5 分钟，留一点余量。
  static const Duration _freshFor = Duration(minutes: 4);

  /// 整个挑战的时间预算。超过就放行，不让用户干等。
  static const Duration _budget = Duration(seconds: 6);

  static String? _token;
  static DateTime? _tokenAt;

  /// 最近一次「服务端确认通过」的时间，避免每次点击都重跑挑战。
  static DateTime? _verifiedAt;

  /// 挑战跑不出来后，短时间内不再重试，免得每次点击都白等 6 秒。
  static DateTime? _skipUntil;

  static Future<TurnstileOutcome>? _pending;
  static String? _lastFailure;

  /// 打开登录 / 注册页时顺手跑一次，点按钮时就能直接用。
  Future<void> warmUp() async {
    await ensureVerified();
  }

  /// 需要验证就弹出验证框，不需要就直接过；跑不出来也不卡住登录。
  Future<TurnstileOutcome> ensureVerified() {
    final verifiedAt = _verifiedAt;
    if (verifiedAt != null &&
        DateTime.now().difference(verifiedAt) < _freshFor) {
      return Future<TurnstileOutcome>.value(TurnstileOutcome.verified);
    }
    final skipUntil = _skipUntil;
    if (skipUntil != null && DateTime.now().isBefore(skipUntil)) {
      return Future<TurnstileOutcome>.value(TurnstileOutcome.skipped);
    }
    final pending = _pending;
    if (pending != null) return pending;
    final future = _run();
    _pending = future;
    future.whenComplete(() {
      if (identical(_pending, future)) _pending = null;
    });
    return future;
  }

  Future<TurnstileOutcome> _run() async {
    final token = _isFresh ? _token : await _acquire();
    // token 只能用一次，取走即作废。
    _token = null;
    _tokenAt = null;
    if (token == null || token.isEmpty) {
      _lastFailure = _lastErrorCode()?.toDart ?? 'timeout';
      debugPrint('人机验证放行（原因：${_lastFailure ?? 'timeout'}）');
      _skipUntil = DateTime.now().add(const Duration(minutes: 2));
      return TurnstileOutcome.skipped;
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-turnstile',
        body: {'token': token},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        _verifiedAt = DateTime.now();
        return TurnstileOutcome.verified;
      }
      debugPrint('人机验证被拒绝');
      return TurnstileOutcome.rejected;
    } catch (error) {
      debugPrint('人机验证校验请求失败: $error');
      _skipUntil = DateTime.now().add(const Duration(minutes: 2));
      return TurnstileOutcome.skipped;
    }
  }

  bool get _isFresh {
    final at = _tokenAt;
    if (at == null || _token == null) return false;
    return DateTime.now().difference(at) < _freshFor;
  }

  Future<String?> _acquire() async {
    final completer = Completer<String>();
    void finish(String token) {
      if (completer.isCompleted) return;
      _token = token;
      _tokenAt = DateTime.now();
      completer.complete(token);
    }

    final callback = ((JSString token) => finish(token.toDart)).toJS;
    try {
      await _waitVisible();
      // 先 reset 再 execute：否则 execute() 会把上一次已消费的 token 原样返回。
      _resetTurnstile();
      _renderTurnstile(callback);
      _executeTurnstile();
      final token = await completer.future.timeout(
        _budget,
        onTimeout: () => '',
      );
      if (token.isEmpty) {
        _lastFailure = _lastErrorCode()?.toDart ?? 'timeout';
        return null;
      }
      _lastFailure = null;
      return token;
    } catch (_) {
      _lastFailure = 'execute';
      return null;
    }
  }

  /// 挑战必须在可见页面上跑，否则 Turnstile 会反复报 300030。
  Future<void> _waitVisible() {
    final completer = Completer<void>();
    _whenVisible((() {
          if (!completer.isCompleted) completer.complete();
        }).toJS);
    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () {});
  }
}
