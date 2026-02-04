import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/base_entity.dart';
import '../media_service.dart';

/// 统一实体服务
/// 处理所有实体类型（商品、帖子、服务等）的 CRUD 操作
class EntityService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final MediaService _mediaService = MediaService();

  // ============ 读取操作 ============

  /// 获取所有实体（可选按类型过滤）
  /// 返回：BaseEntity 列表
  /// 一次查询获取实体 + 关联媒体
  Future<List<BaseEntity>> fetchEntities({
    String? type,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var queryBuilder = _client.from('entities').select('*, media(*)');

      if (type != null && type.isNotEmpty) {
        queryBuilder = queryBuilder.eq('entity_type', type);
      }

      final query = queryBuilder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query;
      return (response as List)
          .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 获取用户发布的实体
  Future<List<BaseEntity>> fetchUserEntities({
    required String userId,
    String? type,
  }) async {
    try {
      var queryBuilder = _client
          .from('entities')
          .select('*, media(*)')
          .eq('user_id', userId);

      if (type != null && type.isNotEmpty) {
        queryBuilder = queryBuilder.eq('entity_type', type);
      }

      final query = queryBuilder.order('created_at', ascending: false);
      final response = await query;
      return (response as List)
          .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 获取单个实体详情
  Future<BaseEntity?> fetchEntity(String entityId) async {
    try {
      final response = await _client
          .from('entities')
          .select('*, media(*)')
          .eq('id', entityId)
          .maybeSingle();

      if (response == null) return null;
      return BaseEntity.fromJson(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 获取特定类型和位置的实体（用于发现页面）
  /// 例如：查找附近的商品
  Future<List<BaseEntity>> fetchEntitiesByTypeAndLocation({
    required String entityType,
    required String location,
  }) async {
    try {
      final response = await _client
          .from('entities')
          .select('*, media(*)')
          .eq('entity_type', entityType)
          .filter('extra_data->>location', 'eq', location)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ============ 创建操作 ============

  /// 发布新实体
  /// 流程：
  /// 1. 向 entities 表写入基础信息
  /// 2. 如果有媒体，调用 MediaService 上传
  /// 3. 返回完整的 BaseEntity 对象
  Future<BaseEntity> createEntity({
    required String entityType,
    required String title,
    String? content,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final newEntity = {
        'user_id': currentUser.id,
        'entity_type': entityType,
        'title': title,
        'content': content,
        'extra_data': extraData ?? {},
        'created_at': now,
        'updated_at': now,
      };

      final response = await _client
          .from('entities')
          .insert(newEntity)
          .select()
          .single();

      return BaseEntity.fromJson(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 发布实体并上传媒体
  /// 完整流程：创建实体 -> 上传媒体 -> 返回完整对象
  Future<BaseEntity> createEntityWithMedia({
    required String entityType,
    required String title,
    String? content,
    Map<String, dynamic>? extraData,
    List<String>? mediaUrls, // 直接使用的媒体 URL 列表
  }) async {
    try {
      // 1. 创建实体
      final entity = await createEntity(
        entityType: entityType,
        title: title,
        content: content,
        extraData: extraData,
      );

      // 2. 如果有媒体 URL，创建媒体记录
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        final currentUser = _client.auth.currentUser;
        if (currentUser != null) {
          for (int i = 0; i < mediaUrls.length; i++) {
            await _mediaService.createMediaFromUrl(
              userId: currentUser.id,
              entityId: entity.id,
              url: mediaUrls[i],
              mediaType: 'image',
              sortOrder: i,
            );
          }
        }
      }

      // 3. 重新获取完整的实体（包含媒体）
      return await fetchEntity(entity.id) ?? entity;
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ============ 更新操作 ============

  /// 更新实体信息
  Future<BaseEntity> updateEntity({
    required String entityId,
    String? title,
    String? content,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (extraData != null) updates['extra_data'] = extraData;

      final response = await _client
          .from('entities')
          .update(updates)
          .eq('id', entityId)
          .select('*, media(*)')
          .single();

      return BaseEntity.fromJson(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 更新实体的 extraData（灵活更新自定义字段）
  Future<void> updateEntityExtraData({
    required String entityId,
    required Map<String, dynamic> extraDataUpdates,
  }) async {
    try {
      // 先获取当前的 extraData
      final current = await fetchEntity(entityId);
      if (current == null) {
        throw Exception('实体不存在');
      }

      // 合并新数据
      final merged = {...current.extraData, ...extraDataUpdates};

      await _client
          .from('entities')
          .update({
            'extra_data': merged,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', entityId);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ============ 删除操作 ============

  /// 删除实体（同时删除关联的媒体）
  Future<void> deleteEntity(String entityId) async {
    try {
      // 1. 删除关联的媒体
      await _mediaService.deleteMediaByEntity(entityId);

      // 2. 删除实体
      await _client.from('entities').delete().eq('id', entityId);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ============ 互动操作 ============

  /// 点赞/取消点赞实体
  /// 根据 entityType 使用不同的语义化文本
  /// product: "夯" (5分) / "拉" (1分)
  /// blog: "好听" (5分) / "不好听" (1分)
  /// 其他: "赞" (5分) / "踩" (1分)
  /// 返回 true 表示点赞成功，false 表示取消点赞
  Future<bool> toggleVote({
    required String entityId,
    required double score, // 5 或 1
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      if (score != 5 && score != 1) {
        throw Exception('分值只能是 5 或 1');
      }

      // 1. 获取实体信息
      final entity = await fetchEntity(entityId);
      if (entity == null) {
        throw Exception('实体不存在');
      }

      // 2. 检查是否已有该评分记录
      final existing = await _client
          .from('interactions')
          .select()
          .eq('user_id', currentUser.id)
          .eq('entity_id', entityId)
          .eq('interaction_type', _getInteractionType(entity.entityType, score))
          .maybeSingle();

      if (existing != null) {
        // 已存在，删除（取消点赞）
        await _client.from('interactions').delete().eq('id', existing['id']);
        return false; // 返回 false 表示取消点赞
      } else {
        // 不存在，创建（点赞）
        // 首先删除相反的评分（如果存在）
        final oppositeType = _getInteractionType(
          entity.entityType,
          score == 5 ? 1 : 5,
        );

        await _client
            .from('interactions')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('entity_id', entityId)
            .eq('interaction_type', oppositeType);

        // 插入新的评分
        await _client.from('interactions').insert({
          'user_id': currentUser.id,
          'entity_id': entityId,
          'interaction_type': _getInteractionType(entity.entityType, score),
          'score': score,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        return true; // 返回 true 表示点赞成功
      }
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 获取实体的点赞统计
  /// 返回 {'like_count': 10, 'comment_count': 5} 等
  Future<Map<String, int>> getVoteStats(String entityId) async {
    try {
      final response = await _client
          .from('interactions')
          .select('interaction_type')
          .eq('entity_id', entityId);

      final stats = <String, int>{};
      int likeCount = 0;

      for (final item in response as List) {
        final type = item['interaction_type'] as String;
        stats[type] = (stats[type] ?? 0) + 1;

        // 统计点赞数（blog_good, product_good, like）
        if (type == 'blog_good' || type == 'product_good' || type == 'like') {
          likeCount++;
        }
      }

      // 返回格式化后的数据
      stats['like_count'] = likeCount;
      stats['comment_count'] = 0; // 评论功能后续实现

      return stats;
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 检查用户是否已点赞
  Future<bool> hasVoted({
    required String entityId,
    required double score,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return false;

      final entity = await fetchEntity(entityId);
      if (entity == null) return false;

      final existing = await _client
          .from('interactions')
          .select()
          .eq('user_id', currentUser.id)
          .eq('entity_id', entityId)
          .eq('interaction_type', _getInteractionType(entity.entityType, score))
          .maybeSingle();

      return existing != null;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // ============ 辅助方法 ============

  /// 根据实体类型和分值获取交互类型文本
  String _getInteractionType(String entityType, double score) {
    final isPositive = score == 5;

    switch (entityType) {
      case 'product':
        return isPositive ? 'product_good' : 'product_bad';
      case 'blog':
      case 'post':
        return isPositive ? 'blog_good' : 'blog_bad';
      default:
        return isPositive ? 'like' : 'dislike';
    }
  }

  /// 获取交互类型的语义化文本
  String getInteractionLabel(String entityType, String interactionType) {
    switch (interactionType) {
      case 'product_good':
        return '夯';
      case 'product_bad':
        return '拉';
      case 'blog_good':
        return '好听';
      case 'blog_bad':
        return '不好听';
      case 'like':
        return '赞';
      case 'dislike':
        return '踩';
      default:
        return interactionType;
    }
  }

  /// 统一的错误处理
  void _handleError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
      throw Exception('network: $e');
    }
    if (msg.contains('permission') ||
        msg.contains('403') ||
        msg.contains('forbidden') ||
        msg.contains('Unauthorized')) {
      throw Exception('permission: $e');
    }
  }
}
