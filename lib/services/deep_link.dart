import 'package:flutter/foundation.dart';

/// 深链接解析：把 `https://skneo.club/p/<entity_id>` 还原成 entity id。
///
/// 链接直接用 entity id 命名，所以永久有效，不需要额外的短链表。
class DeepLink {
  const DeepLink._();

  static final RegExp _postPath = RegExp(
    r'^/p/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/?$',
  );

  /// 从路径解析帖子 id；不是帖子链接时返回 null。
  static String? postIdFromPath(String path) {
    final match = _postPath.firstMatch(path.trim());
    return match?.group(1);
  }

  /// 当前页面地址里的帖子 id（仅 Web 有效）。
  static String? get initialPostId {
    if (!kIsWeb) return null;
    final uri = Uri.base;
    return postIdFromPath(uri.path) ??
        postIdFromPath(uri.fragment.startsWith('/') ? uri.fragment : '');
  }
}
