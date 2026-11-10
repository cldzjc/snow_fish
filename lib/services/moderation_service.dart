import 'package:supabase_flutter/supabase_flutter.dart';

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
    await _client.from('reports').insert({
      'reporter_id': userId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'details': details,
    });
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
        .select()
        .inFilter('status', ['open', 'reviewing'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> resolveReport({
    required String reportId,
    required String status,
    required String note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('请先登录');
    await _client.from('reports').update({
      'status': status,
      'resolved_by': userId,
      'resolution_note': note,
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
  }

  Future<void> moderateEntity({
    required String entityId,
    required String status,
    required String reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('请先登录');
    await _client.from('entities').update({
      'moderation_status': status,
      'moderation_reason': reason,
      'moderated_by': userId,
      'moderated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', entityId);
    await _client.from('moderation_actions').insert({
      'moderator_id': userId,
      'action_type': status == 'visible' ? 'restore_content' : 'hide_content',
      'target_type': 'entity',
      'target_id': entityId,
      'reason': reason,
    });
  }
}
