import 'package:flutter/foundation.dart';

/// 深链接解析。
///
/// 支持的地址形式：
///   https://skneo.club/<短码>               （短码 = entity id 前 8 位）
///   https://skneo.club/p/<短码或完整 uuid>   （旧链接，继续兼容）
class DeepLink {
  const DeepLink._();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final RegExp _shortCode = RegExp(r'^[0-9a-fA-F]{6,32}$');

  static final RegExp _prefixedPost = RegExp(r'^/p/([0-9a-fA-F-]{6,36})/?$');

  /// 完整 uuid 原样返回，短码返回 null（需要去数据库换出完整 id）。
  static String? asFullUuid(String key) => _uuid.hasMatch(key) ? key : null;

  /// 从路径里取出帖子 key（短码或完整 uuid）。
  static String? keyFromPath(String path) {
    final trimmed = path.trim();
    final prefixed = _prefixedPost.firstMatch(trimmed);
    if (prefixed != null) return prefixed.group(1);
    if (!trimmed.startsWith('/')) return null;
    final bare = trimmed.substring(1).replaceAll('/', '');
    if (_shortCode.hasMatch(bare)) return bare;
    return null;
  }

  /// 当前页面地址里的帖子 key（仅 Web 有效）。
  static String? get initialPostKey {
    if (!kIsWeb) return null;
    final uri = Uri.base;
    return keyFromPath(uri.path) ??
        keyFromPath(uri.fragment.startsWith('/') ? uri.fragment : '');
  }
}
