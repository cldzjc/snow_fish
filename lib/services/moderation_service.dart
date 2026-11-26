import 'package:supabase_flutter/supabase_flutter.dart';
import '../media_service.dart';

class ModerationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('请先登录');
    try {
      await _client.rpc(
        'submit_report',
        params: {
          'p_target_type': targetType,
          'p_target_id': targetId,
          'p_reason': reason,
          'p_details': details,
        },
      );
    } on PostgrestException catch (error) {
      throw StateError(error.message);
    }
  }

  Future<void> blockUser(String userId) async {
    final currentUser = _client.auth.currentUser?.id;
    if (currentUser == null) throw StateError('请先登录');
    if (currentUser == userId) throw StateError('不能拉黑自己');
    await _client.from('user_blocks').upsert({
      'blocker_id': currentUser,
      'blocked_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> loadOpenReports() async {
    final rows = await _client
        .from('reports')
        .select(
          'id, reporter_id, target_type, target_id, reason, details, created_at',
        )
        .inFilter('status', ['open', 'reviewing'])
        .order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final enriched = Map<String, dynamic>.from(row);
      if (row['target_type'] == 'entity') {
        enriched['target'] = await _client
            .from('entities')
            .select(
              'id, title, content, user_id, moderation_status, pinned_at, media(*)',
            )
            .eq('id', row['target_id'])
            .maybeSingle();
      } else if (row['target_type'] == 'comment') {
        enriched['target'] = await _client
            .from('comments')
            .select('id, content, user_id, entity_id, moderation_status')
            .eq('id', row['target_id'])
            .maybeSingle();
      } else {
        enriched['target'] = await _client
            .from('user_profiles')
            .select('id, nickname, avatar_url, account_status')
            .eq('id', row['target_id'])
            .maybeSingle();
      }
      result.add(enriched);
    }
    return result;
  }

  /// 「有错」：封禁用户并隐藏其全部内容（申诉通过后可恢复）。
  Future<int> suspendUser({
    required String userId,
    required String reason,
  }) async {
    if (_client.auth.currentUser == null) throw StateError('请先登录');
    final result = await _client.rpc(
      'admin_suspend_user',
      params: {'p_user_id': userId, 'p_reason': reason},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  /// 「申诉通过」：解封并把因封号隐藏的内容恢复。
  Future<int> restoreUser({
    required String userId,
    required String note,
  }) async {
    if (_client.auth.currentUser == null) throw StateError('请先登录');
    final result = await _client.rpc(
      'admin_restore_user',
      params: {'p_user_id': userId, 'p_note': note},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  /// 已封禁用户，供解封入口使用。
  Future<List<Map<String, dynamic>>> loadSuspendedUsers() async {
    final rows = await _client
        .from('user_profiles')
        .select('id, nickname, avatar_url, account_status_reason, updated_at')
        .eq('account_status', 'suspended')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> resolveReport({
    required String reportId,
    required String status,
    required String note,
    String? targetType,
    String? targetId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('请先登录');
    final decision = status == 'resolved' ? 'remove' : 'dismiss';
    if (decision == 'remove' && targetType == 'entity' && targetId != null) {
      await MediaService().deleteMediaByEntity(targetId);
    }
    await _client.rpc(
      'moderate_report',
      params: {'p_report_id': reportId, 'p_decision': decision, 'p_note': note},
    );
  }

  Future<void> restoreContent({
    required String targetType,
    required String targetId,
    required String note,
  }) async {
    if (_client.auth.currentUser == null) throw StateError('请先登录');
    await _client.rpc(
      'restore_moderated_content',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_note': note,
      },
    );
  }

  Future<void> setEntityPinned({
    required String entityId,
    required bool pinned,
    DateTime? until,
  }) async {
    if (_client.auth.currentUser == null) throw StateError('请先登录');
    await _client.rpc(
      'set_entity_pinned',
      params: {
        'p_entity_id': entityId,
        'p_pinned': pinned,
        'p_until': until?.toUtc().toIso8601String(),
      },
    );
  }
}
