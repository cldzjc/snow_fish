import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/base_entity.dart';
import '../services/entity_service.dart';
import 'post_detail_page.dart';

/// 活动发布成功后通知约约约列表刷新。
final ValueNotifier<int> activityRefreshTick = ValueNotifier<int>(0);

class ActivityListWidget extends StatefulWidget {
  const ActivityListWidget({super.key});

  @override
  State<ActivityListWidget> createState() => _ActivityListWidgetState();
}

class _ActivityListWidgetState extends State<ActivityListWidget>
    with AutomaticKeepAliveClientMixin {
  final EntityService _entityService = EntityService();
  late Future<List<BaseEntity>> _future;
  String _region = '';
  String _activityType = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    activityRefreshTick.addListener(_onExternalRefresh);
    _load();
  }

  @override
  void dispose() {
    activityRefreshTick.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && _region.isEmpty) {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('resident_region')
          .eq('id', user.id)
          .maybeSingle();
      _region = (profile?['resident_region'] as String?)?.trim() ?? '';
    }
    setState(() {
      _future = _entityService.fetchActivities(
        regionId: _region.isEmpty ? null : _region,
        activityType: _activityType.isEmpty ? null : _activityType,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _region.isEmpty ? null : _region,
                  decoration: const InputDecoration(labelText: '浏览地区'),
                  items: const [
                    DropdownMenuItem(value: '北京', child: Text('北京')),
                    DropdownMenuItem(value: '河北', child: Text('河北')),
                    DropdownMenuItem(value: '黑龙江', child: Text('黑龙江')),
                    DropdownMenuItem(value: '吉林', child: Text('吉林')),
                    DropdownMenuItem(value: '辽宁', child: Text('辽宁')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _region = value ?? '';
                      _future = _entityService.fetchActivities(
                        regionId: _region.isEmpty ? null : _region,
                        activityType: _activityType.isEmpty
                            ? null
                            : _activityType,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _activityType.isEmpty ? null : _activityType,
                  decoration: const InputDecoration(labelText: '活动类型'),
                  items: const [
                    DropdownMenuItem(value: 'ski', child: Text('约滑')),
                    DropdownMenuItem(value: 'photo', child: Text('约拍')),
                    DropdownMenuItem(value: 'food', child: Text('约饭')),
                    DropdownMenuItem(value: 'gear', child: Text('约装备')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _activityType = value ?? '';
                      _future = _entityService.fetchActivities(
                        regionId: _region.isEmpty ? null : _region,
                        activityType: _activityType.isEmpty
                            ? null
                            : _activityType,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<BaseEntity>>(
            future: _future,
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('活动加载失败，请稍后重试'));
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('暂无约约约活动'));
              }
              return RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final status =
                        item.extraData['activity_status']?.toString() ??
                        'recruiting';
                    return Card(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.extraData['region_id'] ?? ''} · ${status == 'recruiting' ? '招募中' : status}',
                          maxLines: 2,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailPage(postId: item.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
