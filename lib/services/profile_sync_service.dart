import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSyncService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> ensureCurrentProfile({
    String? registrationName,
    String? residentRegion,
    String? residentResort,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final existing = await _client
        .from('user_profiles')
        .select('id, nickname, resident_region, resident_resort')
        .eq('id', user.id)
        .maybeSingle();

    final existingNickname = (existing?['nickname'] as String?)?.trim();
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final displayName =
        (metadata['display_name'] ?? metadata['name'] as String?)
            ?.toString()
            .trim();
    final preferredName = (registrationName?.trim().isNotEmpty == true)
        ? registrationName!.trim()
        : displayName;

    if (existing == null) {
      await _client.from('user_profiles').insert({
        'id': user.id,
        if (preferredName != null && preferredName.isNotEmpty)
          'nickname': preferredName,
        if (residentRegion != null && residentRegion.trim().isNotEmpty)
          'resident_region': residentRegion.trim(),
        if (residentResort != null) 'resident_resort': residentResort.trim(),
      });
      return;
    }

    if (existingNickname == null || existingNickname.isEmpty) {
      if (preferredName != null && preferredName.isNotEmpty) {
        await _client
            .from('user_profiles')
            .update({'nickname': preferredName})
            .eq('id', user.id);
      }
    }

    if (residentRegion != null && residentRegion.trim().isNotEmpty) {
      await _client
          .from('user_profiles')
          .update({
            'resident_region': residentRegion.trim(),
            if (residentResort != null)
              'resident_resort': residentResort.trim(),
          })
          .eq('id', user.id);
    }
  }

  Future<void> updateNickname(String nickname) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty) throw ArgumentError('昵称不能为空');
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('请先登录');

    await _client
        .from('user_profiles')
        .update({'nickname': normalized})
        .eq('id', user.id);
    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': normalized, 'name': normalized}),
    );
  }
}
