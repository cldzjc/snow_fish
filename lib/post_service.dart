import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class PostService {
  static final SupabaseClient _client = SupabaseClientManager.instance;

  // 获取帖子列表（一次性查询，按 created_at 倒序）
  Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final response = await _client
          .from('posts')
          .select('*')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 创建帖子，自动绑定当前登录用户 id（未登录时抛出）
  Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    required List<String> mediaUrls, // 可为空列表
  }) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('not_logged_in');
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    final authorName =
        (currentUser?.userMetadata?['name'] as String?) ??
        (currentUser?.userMetadata?['nickname'] as String?) ??
        currentUser?.email ??
        '匿名用户';

    final newPost = {
      'title': title,
      'content': content,
      'media_urls': mediaUrls,
      'user_id': currentUserId,
      'author_name': authorName,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _client.from('posts').insert(newPost).select();
      return response.first;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }
}
