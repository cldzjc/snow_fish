import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment_model.dart';

/// 评论服务类 - 处理评论的CRUD操作和业务逻辑
class CommentService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// 创建新评论
  /// [entityId] 帖子/商品ID
  /// [content] 评论内容
  /// [parentId] 父评论ID（回复时使用）
  Future<CommentModel> createComment({
    required String entityId,
    required String content,
    String? parentId,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      if (content.trim().isEmpty) {
        throw Exception('评论内容不能为空');
      }

      // 获取用户资料
      final userProfile = await _client
          .from('user_profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      final nickname =
          (userProfile?['nickname'] as String?) ?? currentUser.email ?? '匿名用户';
      final avatarUrl =
          (userProfile?['avatar_url'] as String?) ??
          'https://api.dicebear.com/7.x/avataaars/svg?seed=${currentUser.id}';

      // 插入评论
      final response = await _client
          .from('comments')
          .insert({
            'entity_id': entityId,
            'user_id': currentUser.id,
            'content': content,
            'parent_id': parentId,
            'author_nickname': nickname,
            'author_avatar': avatarUrl,
            'like_count': 0,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      return CommentModel.fromJson(response);
    } catch (e) {
      print('❌ 创建评论失败: $e');
      rethrow;
    }
  }

  /// 获取评论列表（不包含回复）
  /// [entityId] 帖子/商品ID
  /// [limit] 返回数量
  /// [offset] 偏移量
  Future<List<CommentModel>> getComments({
    required String entityId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select()
          .eq('entity_id', entityId)
          .isFilter('parent_id', null) // 只获取顶级评论
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((item) => CommentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ 获取评论失败: $e');
      rethrow;
    }
  }

  /// 获取评论的回复列表
  /// [parentCommentId] 父评论ID
  Future<List<CommentModel>> getReplies({
    required String parentCommentId,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select()
          .eq('parent_id', parentCommentId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => CommentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ 获取回复失败: $e');
      rethrow;
    }
  }

  /// 构建评论树（带嵌套回复）
  /// [comments] 顶级评论列表
  /// [replies] 所有回复列表
  static List<CommentModel> buildCommentTree(
    List<CommentModel> comments,
    Map<String, List<CommentModel>> repliesMap,
  ) {
    return comments.map((comment) {
      final replies = repliesMap[comment.id] ?? [];
      return comment.copyWith(replies: replies);
    }).toList();
  }

  /// 获取完整的评论树（包含所有回复）
  Future<List<CommentModel>> getCommentTree({required String entityId}) async {
    try {
      // 获取所有顶级评论
      final topLevelComments = await getComments(
        entityId: entityId,
        limit: 1000,
      );

      // 获取所有回复
      final repliesMap = <String, List<CommentModel>>{};
      for (final comment in topLevelComments) {
        final replies = await getReplies(parentCommentId: comment.id);
        repliesMap[comment.id] = replies;
      }

      // 构建评论树
      return buildCommentTree(topLevelComments, repliesMap);
    } catch (e) {
      print('❌ 获取评论树失败: $e');
      rethrow;
    }
  }

  /// 更新评论内容
  Future<CommentModel> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      // 验证是否是评论者
      final comment = await _client
          .from('comments')
          .select()
          .eq('id', commentId)
          .maybeSingle();

      if (comment == null) {
        throw Exception('评论不存在');
      }

      if (comment['user_id'] != currentUser.id) {
        throw Exception('您没有权限编辑此评论');
      }

      final response = await _client
          .from('comments')
          .update({
            'content': content,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', commentId)
          .select()
          .single();

      return CommentModel.fromJson(response);
    } catch (e) {
      print('❌ 更新评论失败: $e');
      rethrow;
    }
  }

  /// 删除评论（同时删除其所有回复）
  Future<void> deleteComment({required String commentId}) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      // 验证是否是评论者
      final comment = await _client
          .from('comments')
          .select()
          .eq('id', commentId)
          .maybeSingle();

      if (comment == null) {
        throw Exception('评论不存在');
      }

      if (comment['user_id'] != currentUser.id) {
        throw Exception('您没有权限删除此评论');
      }

      // 删除所有回复
      await _client.from('comments').delete().eq('parent_id', commentId);

      // 删除评论本身
      await _client.from('comments').delete().eq('id', commentId);
    } catch (e) {
      print('❌ 删除评论失败: $e');
      rethrow;
    }
  }

  /// 点赞评论
  Future<bool> toggleCommentLike({required String commentId}) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      // 检查是否已点赞
      final existing = await _client
          .from('interactions')
          .select()
          .eq('user_id', currentUser.id)
          .eq('entity_id', commentId)
          .eq('interaction_type', 'comment_like')
          .maybeSingle();

      if (existing != null) {
        // 已点赞，删除点赞
        await _client.from('interactions').delete().eq('id', existing['id']);

        // 更新评论的点赞数
        await _client.rpc(
          'decrement_comment_likes',
          params: {'comment_id': commentId},
        );
        return false;
      } else {
        // 未点赞，添加点赞
        await _client.from('interactions').insert({
          'user_id': currentUser.id,
          'entity_id': commentId,
          'interaction_type': 'comment_like',
          'score': 1,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // 更新评论的点赞数
        await _client.rpc(
          'increment_comment_likes',
          params: {'comment_id': commentId},
        );
        return true;
      }
    } catch (e) {
      print('❌ 点赞评论失败: $e');
      rethrow;
    }
  }

  /// 检查用户是否点赞了评论
  Future<bool> hasCommentLiked({required String commentId}) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return false;

      final existing = await _client
          .from('interactions')
          .select()
          .eq('user_id', currentUser.id)
          .eq('entity_id', commentId)
          .eq('interaction_type', 'comment_like')
          .maybeSingle();

      return existing != null;
    } catch (e) {
      print('❌ 检查点赞状态失败: $e');
      return false;
    }
  }

  /// 获取评论数量
  Future<int> getCommentCount({required String entityId}) async {
    try {
      final response = await _client
          .from('comments')
          .select('id')
          .eq('entity_id', entityId)
          .isFilter('parent_id', null); // 只计算顶级评论

      return (response as List).length;
    } catch (e) {
      print('❌ 获取评论数失败: $e');
      return 0;
    }
  }
}
