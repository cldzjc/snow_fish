import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/entity_service.dart';
import '../constants/geo.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/app/status_chip.dart';
import 'post_detail_page.dart';

/// 活动发布后触发列表刷新。
final ValueNotifier<int> activityRefreshTick = ValueNotifier<int>(0);

class ActivityListWidget extends StatefulWidget {
  const ActivityListWidget({super.key});

  @override
  State<ActivityListWidget> createState() => ActivityListWidgetState();
}

class ActivityListWidgetState extends State<ActivityListWidget>
    with AutomaticKeepAliveClientMixin {
  static final List<AppOption<String>> _regionOptions = <AppOption<String>>[
    const AppOption<String>('', '全部地区'),
    for (final region in GeoData.provinces) AppOption<String>(region, region),
  ];

  static const List<AppOption<String>> _typeOptions = <AppOption<String>>[
    AppOption<String>('', '全部类型'),
    AppOption<String>('ski', '约滑'),
    AppOption<String>('photo', '约拍'),
    AppOption<String>('food', '约饭'),
    AppOption<String>('gear', '约装备'),
  ];

  final EntityService _entityService = EntityService();

  String _region = '';
  String _type = '';
  bool _loading = true;
  String? _error;
  List<BaseEntity> _items = <BaseEntity>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    activityRefreshTick.addListener(_onExternalRefresh);
    _load(initial: true);
  }

  @override
  void dispose() {
    activityRefreshTick.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) _load(showSkeleton: false);
  }

  /// 供首页下拉刷新调用；返回真实请求完成后的 Future。
  Future<void> refreshNow() => _load(showSkeleton: false);

  Future<void> _load({bool initial = false, bool showSkeleton = true}) async {
    if (initial) {
      // 首次进入时把常驻地区作为默认浏览地区，没有则看全部。
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final row = await Supabase.instance.client
              .from('user_profiles')
              .select('resident_region')
              .eq('id', user.id)
              .maybeSingle();
          final region = (row?['resident_region'] as String?)?.trim() ?? '';
          if (GeoData.provinces.contains(region)) _region = region;
        } catch (_) {
          // 读取失败时保持「全部地区」。
        }
      }
    }
    if (!mounted) return;
    setState(() {
      if (showSkeleton) _loading = true;
      _error = null;
    });
    try {
      final items = await _entityService.fetchActivities(
        regionId: _region.isEmpty ? null : _region,
        activityType: _type.isEmpty ? null : _type,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppDropdown<String>(
                  options: _regionOptions,
                  value: _region,
                  onChanged: (value) {
                    setState(() => _region = value ?? '');
                    _load();
                  },
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: AppDropdown<String>(
                  options: _typeOptions,
                  value: _type,
                  onChanged: (value) {
                    setState(() => _type = value ?? '');
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingSkeleton(rows: 2);
    if (_error != null) {
      return AppStateView.error(onRetry: _load);
    }
    if (_items.isEmpty) {
      return const AppStateView(
        icon: AppIcons.mountain,
        title: '还没有活动',
        description: '换个地区，或者发起一次新的相约。',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, index) => _ActivityRow(
        activity: _items[index],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailPage(postId: _items[index].id),
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onTap});

  final BaseEntity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final region = activity.extraData['region_id']?.toString().trim() ?? '';
    final resort = activity.extraData['resort_id']?.toString().trim() ?? '';
    final place = [region, resort].where((item) => item.isNotEmpty).join(' · ');

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    activityIcon(activity.entityType),
                    size: 18,
                    color: colors.muted,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      activity.title,
                      style: AppText.title.copyWith(color: colors.ink),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  ActivityStatusChip(
                    status:
                        activity.extraData['activity_status']?.toString() ??
                        'recruiting',
                  ),
                ],
              ),
              if (place.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Text(place, style: AppText.meta.copyWith(color: colors.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
