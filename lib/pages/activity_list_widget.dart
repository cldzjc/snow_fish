import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../models/refresh_result.dart';
import '../services/entity_service.dart';
import '../services/feed_cache.dart';
import '../constants/geo.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/geo_format.dart';
import '../widgets/app/activity_form_sheets.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/app/status_chip.dart';
import 'post_detail_page.dart';

/// 活动发布后触发列表刷新。
final ValueNotifier<int> activityRefreshTick = ValueNotifier<int>(0);

class ActivityListWidget extends StatefulWidget {
  const ActivityListWidget({super.key, this.topInset = 0});

  /// 列表顶部的留白（属于滚动内容，会随列表一起滚走）。
  final double topInset;

  @override
  State<ActivityListWidget> createState() => ActivityListWidgetState();
}

class ActivityListWidgetState extends State<ActivityListWidget>
    with AutomaticKeepAliveClientMixin {
  static const List<AppOption<String>> _typeOptions = <AppOption<String>>[
    AppOption<String>('', '全部类型'),
    AppOption<String>('ski', '约滑'),
    AppOption<String>('photo', '约拍'),
    AppOption<String>('food', '约饭'),
  ];

  final EntityService _entityService = EntityService();

  ActivityPlaceFilter _place = const ActivityPlaceFilter();
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

  /// 下拉刷新：返回相比刷新前「新增」的条数。
  Future<RefreshResult> refreshNow() async {
    await _load(showSkeleton: false);
    if (_error != null) return RefreshResult.failure;
    return RefreshResult(newCount: _lastNewCount, total: _items.length);
  }

  int _lastNewCount = 0;

  Future<void> _load({bool initial = false, bool showSkeleton = true}) async {
    if (!mounted) return;
    setState(() {
      if (showSkeleton) _loading = true;
      _error = null;
    });
    final key = FeedCache.activitiesKey(
      region: _place.region,
      resort: _place.resort,
      type: _type,
    );
    Future<List<BaseEntity>> fetch() => _entityService.fetchActivities(
      regionId: _place.region.isEmpty ? null : _place.region,
      resortId: _place.resort.isEmpty ? null : _place.resort,
      activityType: _type.isEmpty ? null : _type,
    );
    try {
      // 开屏预取过「全部类型 / 全部地点」，首屏直接命中。
      final items = initial || showSkeleton
          ? await FeedCache.load<List<BaseEntity>>(key, fetch)
          : await FeedCache.refresh<List<BaseEntity>>(key, fetch);
      if (!mounted) return;
      final known = _items.map((item) => item.id).toSet();
      _lastNewCount = known.isEmpty
          ? items.length
          : items.where((item) => !known.contains(item.id)).length;
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

  Future<void> _pickPlace() async {
    final picked = await showActivityPlaceSheet(context, current: _place);
    if (picked == null || !mounted) return;
    setState(() => _place = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildBody();
  }

  /// 筛选行跟着列表一起滚走，避免顶栏沉浸式收起后留下空白。
  Widget _filters() {
    return Padding(
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
              options: _typeOptions,
              value: _type,
              onChanged: (value) {
                setState(() => _type = value ?? '');
                _load();
              },
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: _PlaceFilterButton(
              label: _place.label,
              active: !_place.isEmpty,
              onTap: _pickPlace,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(top: widget.topInset),
        child: const AppLoadingSkeleton(rows: 2),
      );
    }
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.only(top: widget.topInset),
        child: AppStateView.error(onRetry: _load),
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: widget.topInset),
        children: [
          _filters(),
          const SizedBox(height: AppSpace.xxxl),
          const AppStateView(
            icon: AppIcons.mountain,
            title: '还没有活动',
            description: '还没有人发起，你可以做第一个。',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: widget.topInset, bottom: 92),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, index) {
        if (index == 0) return _filters();
        final activity = _items[index - 1];
        return _ActivityRow(
          activity: activity,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailPage(postId: activity.id),
            ),
          ),
        );
      },
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
    final place = shortRegionLabel(region: region, resort: resort);

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

/// 地点筛选按钮：外观和下拉框一致，点击打开两级面板。
class _PlaceFilterButton extends StatelessWidget {
  const _PlaceFilterButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        decoration: BoxDecoration(
          color: colors.soft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall.copyWith(
                  color: active ? colors.ink : colors.muted,
                ),
              ),
            ),
            Icon(AppIcons.chevron, size: 16, color: colors.muted),
          ],
        ),
      ),
    );
  }
}