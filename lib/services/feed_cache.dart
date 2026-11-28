import 'dart:async';

/// 首屏列表的共享缓存。
///
/// 开屏动画期间会先预取一次，页面挂载时直接复用同一份结果：
/// 既避免「预取一份、页面再拉一份」的重复请求，也让首屏不用等网络。
class FeedCache {
  FeedCache._();

  /// 超过这个时间的缓存不再直接使用（下拉刷新会主动换新）。
  static const Duration maxAge = Duration(seconds: 60);

  static const String homeKey = 'home';

  static String activitiesKey({
    String region = '',
    String resort = '',
    String type = '',
  }) => 'activities:$region|$resort|$type';

  static String circleKey(List<String> scope) => 'circle:${scope.join(',')}';

  static final Map<String, _Entry> _done = <String, _Entry>{};
  static final Map<String, Future<Object?>> _running =
      <String, Future<Object?>>{};

  /// 命中未过期的缓存时直接返回，同时并入进行中的请求。
  static Future<T> load<T>(String key, Future<T> Function() fetch) {
    final cached = peek<T>(key);
    if (cached != null) return Future<T>.value(cached);
    final running = _running[key];
    if (running != null) return running.then((value) => value as T);
    final future = fetch();
    _running[key] = future;
    future.then<void>(
      (value) {
        _done[key] = _Entry(value, DateTime.now());
      },
      onError: (Object _) {},
    ).whenComplete(() => _running.remove(key));
    return future;
  }

  /// 强制换新：先丢掉旧值，再复用同一个请求通道。
  static Future<T> refresh<T>(String key, Future<T> Function() fetch) {
    _done.remove(key);
    return load<T>(key, fetch);
  }

  static T? peek<T>(String key) {
    final entry = _done[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > maxAge) return null;
    final value = entry.value;
    return value is T ? value : null;
  }

  /// 发布 / 删除内容后清掉，避免读到旧列表。
  static void invalidate(Iterable<String> keys) {
    for (final key in keys) {
      _done.remove(key);
      _running.remove(key);
    }
  }

  static void clear() {
    _done.clear();
    _running.clear();
  }
}

class _Entry {
  const _Entry(this.value, this.at);

  final Object? value;
  final DateTime at;
}
