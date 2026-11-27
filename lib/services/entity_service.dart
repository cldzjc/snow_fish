import 'package:flutter/foundation.dart';
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

  /// 获取 sk社区帖子，置顶内容优先（仅首页第一页包含置顶）
  ///
  /// 圈子里的帖子不进 sk社区，用 `circle_id is null` 把两者分开。
  Future<List<BaseEntity>> fetchSkCommunity({
    int limit = 20,
    int offset = 0,
  }) async {
    final normal = await _communityPage(limit: limit, offset: offset);
    final normalItems = (normal as List)
        .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
        .toList();

    if (offset > 0) return normalItems;

    final now = DateTime.now().toUtc().toIso8601String();
    final pinned = await _communityPinned(now);
    final pinnedItems = (pinned as List)
        .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
        .toList();
    if (pinnedItems.isEmpty) return normalItems;

    final pinnedIds = pinnedItems.map((item) => item.id).toSet();
    return [
      ...pinnedItems,
      ...normalItems.where((item) => !pinnedIds.contains(item.id)),
    ];
  }

  /// sk社区列表查询。
  ///
  /// 如果 `entities.circle_id` 还没建（圈子迁移没跑），退回不过滤的旧查询，
  /// 保证首页信息流不会因为字段缺失整屏报错。
  Future<dynamic> _communityPage({
    required int limit,
    required int offset,
  }) async {
    try {
      return await _client
          .from('entities')
          .select('*, media(*)')
          .eq('entity_type', 'post')
          .eq('moderation_status', 'visible')
          .isFilter('circle_id', null)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (error) {
      debugPrint('sk社区查询（含圈子过滤）失败，回退基础查询: $error');
      return await _client
          .from('entities')
          .select('*, media(*)')
          .eq('entity_type', 'post')
          .eq('moderation_status', 'visible')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    }
  }

  Future<dynamic> _communityPinned(String now) async {
    try {
      return await _client
          .from('entities')
          .select('*, media(*)')
          .eq('entity_type', 'post')
          .eq('moderation_status', 'visible')
          .isFilter('circle_id', null)
          .not('pinned_at', 'is', null)
          .or('pinned_until.is.null,pinned_until.gt.$now')
          .order('pinned_at', ascending: false)
          .range(0, 49);
    } catch (error) {
      debugPrint('置顶查询（含圈子过滤）失败，回退基础查询: $error');
      return await _client
          .from('entities')
          .select('*, media(*)')
          .eq('entity_type', 'post')
          .eq('moderation_status', 'visible')
          .not('pinned_at', 'is', null)
          .or('pinned_until.is.null,pinned_until.gt.$now')
          .order('pinned_at', ascending: false)
          .range(0, 49);
    }
  }

  /// 获取圈子信息流。
  ///
  /// [circleIds] 由 CircleRepository.scopeIds 给出：区县圈会把旗下雪场圈一起带上。
  Future<List<BaseEntity>> fetchCirclePosts({
    required List<String> circleIds,
    int limit = 20,
    int offset = 0,
  }) async {
    if (circleIds.isEmpty) return const <BaseEntity>[];
    final rows = await _client
        .from('entities')
        .select('*, media(*)')
        .eq('entity_type', 'post')
        .eq('moderation_status', 'visible')
        .inFilter('circle_id', circleIds)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 获取约约约活动列表
  /// 约约约看板：只返回还在招募、且还没开始的活动，按开始时间升序。
  ///
  /// 满员 / 已开始 / 已结束的活动由发起者或时间推进，这里统一过滤掉，
  /// 避免「点进去发现报名不了」。
  Future<List<BaseEntity>> fetchActivities({
    String? regionId,
    String? resortId,
    String? activityType,
  }) async {
    var query = _client
        .from('entities')
        .select('*, media(*)')
        .inFilter('entity_type', activityEntityTypes)
        .eq('moderation_status', 'visible');
    if (regionId != null && regionId.isNotEmpty) {
      // 老活动只记到省份，新活动记到区县，用前缀匹配两种都能命中。
      query = query.like('extra_data->>region_id', '$regionId%');
    }
    if (resortId != null && resortId.isNotEmpty) {
      query = query.filter('extra_data->>resort_id', 'eq', resortId);
    }
    if (activityType != null && activityType.isNotEmpty) {
      query = query.filter('extra_data->>activity_type', 'eq', activityType);
    }
    final response = await query.limit(200);
    final now = DateTime.now();
    final items = (response as List)
        .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
        .where((item) => isActivityOpen(item, now))
        .toList();
    items.sort((a, b) {
      final left = activityStartAt(a);
      final right = activityStartAt(b);
      if (left == null && right == null) return b.createdAt.compareTo(a.createdAt);
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
    return items;
  }

  /// 活动类型（entity_type）。
  static const List<String> activityEntityTypes = <String>[
    'activity_ski',
    'activity_photo',
    'activity_food',
    'activity_gear',
  ];

  /// 活动开始时间，未填时为 null。
  static DateTime? activityStartAt(BaseEntity activity) {
    final raw = activity.extraData['start_at']?.toString() ?? '';
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// 是否还在招募中（未满员、未开始、未被取消）。
  static bool isActivityOpen(BaseEntity activity, [DateTime? now]) {
    final extra = activity.extraData;
    final status = extra['activity_status']?.toString() ?? 'recruiting';
    if (status != 'recruiting') return false;
    final start = activityStartAt(activity);
    if (start != null && !start.isAfter(now ?? DateTime.now())) return false;
    return true;
  }

  /// 我发起的活动
  Future<List<BaseEntity>> fetchMyCreatedActivities() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final response = await _client
        .from('entities')
        .select('*, media(*)')
        .eq('user_id', uid)
        .inFilter('entity_type', const [
          'activity_ski',
          'activity_photo',
          'activity_food',
          'activity_gear',
        ])
        .order('created_at', ascending: false);
    return (response as List)
        .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 我参与的（已报名）活动
  Future<List<BaseEntity>> fetchMyJoinedActivities() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('activity_participants')
        .select('entity_id')
        .eq('user_id', uid)
        .eq('status', 'joined');
    final ids = (rows as List)
        .map((row) => row['entity_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];
    final response = await _client
        .from('entities')
        .select('*, media(*)')
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    return (response as List)
        .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 判断活动是否已结束（时间已过或状态为 ended）
  bool isActivityEnded(BaseEntity activity) {
    final status = activity.extraData['activity_status']?.toString();
    if (status == 'ended') return true;
    final startAt = DateTime.tryParse(
      activity.extraData['start_at']?.toString() ?? '',
    );
    if (startAt == null) return false;
    return startAt.isBefore(DateTime.now());
  }

  /// 批量获取实体点赞数（来自 interaction_counters）。
  Future<Map<String, int>> fetchLikeCounts(List<String> entityIds) async {
    if (entityIds.isEmpty) return {};
    final rows = await _client
        .from('interaction_counters')
        .select('target_id, like_count')
        .eq('target_type', 'entity')
        .inFilter('target_id', entityIds);
    return {
      for (final row in rows as List)
        row['target_id'] as String: (row['like_count'] as num?)?.toInt() ?? 0,
    };
  }

  /// 批量判断当前用户点赞过哪些实体。
  Future<Set<String>> fetchLikedEntityIds(List<String> entityIds) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || entityIds.isEmpty) return <String>{};
    final rows = await _client
        .from('interactions')
        .select('entity_id')
        .eq('user_id', uid)
        .eq('target_type', 'entity')
        .inFilter('interaction_type', const [
          'like',
          'blog_good',
          'product_good',
        ])
        .inFilter('entity_id', entityIds);
    return (rows as List).map((row) => row['entity_id'] as String).toSet();
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

  /// 用短码（entity id 前 8 位）换出完整 id。
  ///
  /// 走 uuid 范围查询而不是表达式过滤，这样仍然受 RLS 约束：
  /// 被隐藏或不可见的内容不会被解析出来。
  Future<String?> resolveEntityIdByShortCode(String code) async {
    final prefix = code.replaceAll('-', '').toLowerCase();
    if (prefix.length < 6) return null;
    final head = prefix.length > 8 ? prefix.substring(0, 8) : prefix;
    final lower = '${head.padRight(8, '0')}-0000-0000-0000-000000000000';
    final upper = '${head.padRight(8, 'f')}-ffff-ffff-ffff-ffffffffffff';
    try {
      final rows = await _client
          .from('entities')
          .select('id')
          .gte('id', lower)
          .lte('id', upper)
          .order('created_at')
          .limit(1);
      if ((rows as List).isEmpty) return null;
      return rows.first['id'] as String?;
    } catch (e) {
      _handleError(e);
      return null;
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
    String? circleId,
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
        if (circleId != null && circleId.isNotEmpty) 'circle_id': circleId,
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
    String? circleId,
  }) async {
    try {
      // 1. 创建实体
      final entity = await createEntity(
        entityType: entityType,
        title: title,
        content: content,
        extraData: extraData,
        circleId: circleId,
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
    String? circleId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (extraData != null) updates['extra_data'] = extraData;
      if (circleId != null) {
        updates['circle_id'] = circleId.isEmpty ? null : circleId;
      }

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

  // ============ C2C 专用操作 ============

  /// 切换商品的隐藏状态（卖家可手动隐藏/显示商品）
  /// 返回更新后的实体
  Future<BaseEntity?> toggleEntityHidden({
    required String entityId,
    required bool isHidden,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      // 检查权限：只有发布者可以隐藏自己的商品
      final entity = await fetchEntity(entityId);
      if (entity == null || entity.userId != currentUser.id) {
        throw Exception('权限不足');
      }

      return await updateEntity(
        entityId: entityId,
        extraData: {...entity.extraData, 'is_hidden': isHidden},
      );
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 获取用户发布的所有商品（包括已隐藏）
  /// 用于"我发布的"页面
  Future<List<BaseEntity>> getMyListings({
    String? userId,
    String entityType = 'product',
  }) async {
    try {
      final targetUserId = userId ?? _client.auth.currentUser?.id;
      if (targetUserId == null) return [];

      final response = await _client
          .from('entities')
          .select('*, media(*)')
          .eq('user_id', targetUserId)
          .eq('entity_type', entityType)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 查询已审核且未隐藏的商品（用于首页展示）
  /// 仅返回前端可显示的商品
  Future<List<BaseEntity>> queryProductsByAuditStatus({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // 先查询商品，再在客户端按 C2C 规则过滤，避免 JSON 路径过滤兼容性问题
      final response = await _client
          .from('entities')
          .select('*, media(*)')
          .eq('entity_type', 'product')
          .order('created_at', ascending: false);

      final allProducts = (response as List)
          .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
          .toList();

      final visibleProducts = allProducts
          .where((item) => item.auditStatus == 'approved' && !item.isHidden)
          .toList();

      if (offset >= visibleProducts.length) {
        return [];
      }

      final end = (offset + limit) > visibleProducts.length
          ? visibleProducts.length
          : (offset + limit);

      return visibleProducts.sublist(offset, end);
    } catch (e) {
      _handleError(e);
      // 降级处理：如果过滤失败，返回空列表而不是抛异常
      return [];
    }
  }

  /// 商品关键词搜索（多词 AND，单词跨字段 OR）
  /// 示例：atomic s9 fis165
  Future<List<BaseEntity>> searchProductsByKeywords({
    required String keyword,
    int limit = 50,
  }) async {
    try {
      final normalized = keyword.toLowerCase().trim();
      if (normalized.isEmpty) {
        return queryProductsByAuditStatus(limit: limit);
      }

      final terms = normalized
          .split(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'))
          .where((t) => t.isNotEmpty)
          .toList();

      if (terms.isEmpty) {
        return queryProductsByAuditStatus(limit: limit);
      }

      final response = await _client
          .from('entities')
          .select('*, media(*)')
          .eq('entity_type', 'product')
          .order('created_at', ascending: false)
          .limit(300);

      final allProducts = (response as List)
          .map((item) => BaseEntity.fromJson(item as Map<String, dynamic>))
          .toList();

      final visibleProducts = allProducts
          .where((item) => item.auditStatus == 'approved' && !item.isHidden)
          .where((item) {
            final text = [
              item.title,
              item.content ?? '',
              item.sellerName,
              '${item.location ?? ''}',
              item.conditionLevel,
            ].join(' ').toLowerCase();

            return terms.every((term) => text.contains(term));
          })
          .toList();

      return visibleProducts.take(limit).toList();
    } catch (e) {
      _handleError(e);
      return [];
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
      // 写入只使用 like / dislike：interactions 的 RLS 只放行这两个（外加 favorite），
      // 历史数据里的 blog_good / product_good 仍然按同一语义读出来。
      final type = _voteType(score);
      final existing = await _client
          .from('interactions')
          .select()
          .eq('user_id', currentUser.id)
          .eq('target_type', 'entity')
          .eq('entity_id', entityId)
          .inFilter('interaction_type', _voteTypeAliases(score))
          .maybeSingle();

      if (existing != null) {
        // 已存在，删除（取消点赞）
        await _client.from('interactions').delete().eq('id', existing['id']);
        return false; // 返回 false 表示取消点赞
      } else {
        // 不存在，创建（点赞）
        // 首先删除相反的评分（如果存在）
        final oppositeTypes = _voteTypeAliases(score == 5 ? 1 : 5);

        await _client
            .from('interactions')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('target_type', 'entity')
            .eq('entity_id', entityId)
            .inFilter('interaction_type', oppositeTypes);

        // 插入新的评分
        await _client.from('interactions').insert({
          'user_id': currentUser.id,
          'target_type': 'entity',
          'entity_id': entityId,
          'interaction_type': type,
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
      try {
        final counter = await _client
            .from('interaction_counters')
            .select('like_count, dislike_count')
            .eq('target_type', 'entity')
            .eq('target_id', entityId)
            .maybeSingle();

        if (counter != null) {
          return {
            'like_count': (counter['like_count'] as num?)?.toInt() ?? 0,
            'dislike_count': (counter['dislike_count'] as num?)?.toInt() ?? 0,
            'comment_count': 0,
          };
        }
      } catch (_) {
        // 计数表还未就绪时，回退到明细表。
      }

      final response = await _client
          .from('interactions')
          .select('interaction_type')
          .eq('target_type', 'entity')
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
          .eq('target_type', 'entity')
          .eq('entity_id', entityId)
          .inFilter('interaction_type', _voteTypeAliases(score))
          .maybeSingle();

      return existing != null;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  Future<bool> toggleFavorite(String entityId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw Exception('用户未登录');

    final existing = await _client
        .from('interactions')
        .select('id')
        .eq('user_id', currentUser.id)
        .eq('target_type', 'entity')
        .eq('entity_id', entityId)
        .eq('interaction_type', 'favorite')
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      await _client.from('interactions').delete().eq('id', existing['id']);
      return false;
    }

    await _client.from('interactions').insert({
      'user_id': currentUser.id,
      'target_type': 'entity',
      'entity_id': entityId,
      'interaction_type': 'favorite',
      'score': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return true;
  }

  Future<bool> hasFavorite(String entityId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return false;

    final existing = await _client
        .from('interactions')
        .select('id')
        .eq('user_id', currentUser.id)
        .eq('target_type', 'entity')
        .eq('entity_id', entityId)
        .eq('interaction_type', 'favorite')
        .limit(1)
        .maybeSingle();
    return existing != null;
  }

  /// 申请参加活动（必须由发起者同意才算加入）。
  ///
  /// [phone] 只在当前用户还没填过手机号时传一次，服务端会顺手存下来。
  Future<String> requestJoinActivity(String entityId, {String? phone}) async {
    final result = await _client.rpc(
      'activity_request_join',
      params: {
        'p_entity_id': entityId,
        if (phone != null && phone.isNotEmpty) 'p_phone': phone,
      },
    );
    return result is String ? result : '';
  }

  /// 发起者处理一条申请。
  Future<void> respondActivityRequest(
    String requestId, {
    required bool accept,
  }) async {
    await _client.rpc(
      'activity_respond_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
  }

  /// 取对方手机号：发起者拿申请人的，申请人（被同意后）拿发起者的。
  Future<String> activityContact(String requestId) async {
    final result = await _client.rpc(
      'activity_contact',
      params: {'p_request_id': requestId},
    );
    return result is String ? result : '';
  }

  /// 撤销申请或取消已同意的报名。
  Future<bool> cancelActivityRequest(String entityId) async {
    final result = await _client.rpc(
      'activity_cancel_request',
      params: {'p_entity_id': entityId},
    );
    return result == true;
  }

  /// 当前用户对某个活动的申请记录（id + status），没有则为 null。
  Future<Map<String, dynamic>?> myActivityRequest(String entityId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('activity_requests')
          .select('id, status')
          .eq('entity_id', entityId)
          .eq('applicant_id', uid)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  // ============ 辅助方法 ============

  /// 写入 interactions 时使用的交互类型。
  ///
  /// 数据库 RLS 策略 interactions_insert_self 只放行
  /// entity 的 like / dislike / favorite 与评论的 comment_like，
  /// 所以点赞统一写 like，不再按实体类型派生 blog_good / product_good。
  String _voteType(double score) => score == 5 ? 'like' : 'dislike';

  /// 读取历史记录时要兼容旧的交互类型。
  List<String> _voteTypeAliases(double score) {
    if (score == 5) return const ['like', 'blog_good', 'product_good'];
    return const ['dislike', 'blog_bad', 'product_bad'];
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
