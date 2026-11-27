import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../constants/geo.dart';
import '../../services/contact_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/error_text.dart';
import '../../utils/geo_format.dart';
import 'app_button.dart';
import 'app_field.dart';
import 'app_icons.dart';

/// 面板的统一外壳：拖拽条 + 标题 + 关闭。
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpace.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.pageTitle.copyWith(color: colors.ink),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            subtitle!,
                            style: AppText.caption.copyWith(
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.soft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.close, size: 16, color: colors.ink),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                ],
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// 手机号填写面板。返回填好并保存的号码，取消则返回 null。
Future<String?> showPhoneSheet(
  BuildContext context, {
  String? initial,
  String title = '填写手机号',
  String hint = '仅用于活动双方联系，不会显示在个人主页',
  bool required = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PhoneSheet(
      initial: initial,
      title: title,
      hint: hint,
      required: required,
    ),
  );
}

class _PhoneSheet extends StatefulWidget {
  const _PhoneSheet({
    required this.title,
    required this.hint,
    required this.initial,
    required this.required,
  });

  final String title;
  final String hint;
  final String? initial;
  final bool required;

  @override
  State<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<_PhoneSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _controller.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写正确的 11 位手机号')));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ContactService().save(phone);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '保存失败'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetShell(
        title: widget.title,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            0,
            AppSpace.xl,
            AppSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.hint,
                style: AppText.bodySmall.copyWith(color: colors.muted),
              ),
              const SizedBox(height: AppSpace.lg),
              AppTextField(
                controller: _controller,
                hint: '11 位手机号',
                keyboardType: TextInputType.phone,
                autofocus: true,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                '参加活动用得上哦，现在不填的话在主页也能编辑。',
                style: AppText.caption.copyWith(color: colors.muted),
              ),
              const SizedBox(height: AppSpace.xl),
              AppButton(
                label: '保存',
                expand: true,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              if (!widget.required) ...[
                const SizedBox(height: AppSpace.sm),
                Center(
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('以后再说'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 雪场搜索面板：输入关键字本地过滤，零网络请求。
Future<String?> showResortSheet(
  BuildContext context, {
  required List<String> options,
  String? selected,
  bool allowNone = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ResortSheet(
      options: options,
      selected: selected,
      allowNone: allowNone,
    ),
  );
}

class _ResortSheet extends StatefulWidget {
  const _ResortSheet({
    required this.options,
    required this.selected,
    required this.allowNone,
  });

  final List<String> options;
  final String? selected;
  final bool allowNone;

  @override
  State<_ResortSheet> createState() => _ResortSheetState();
}

class _ResortSheetState extends State<_ResortSheet> {
  final TextEditingController _search = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final key = _keyword.trim();
    if (key.isEmpty) return widget.options;
    return widget.options
        .where((item) => item.contains(key))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _filtered;
    return SheetShell(
      title: '选择雪场',
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                AppSpace.md,
              ),
              child: AppTextField(
                controller: _search,
                hint: '输入雪场名，例如 富龙',
                onChanged: (value) => setState(() => _keyword = value),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '没有找到「${_keyword.trim()}」',
                        style: AppText.bodySmall.copyWith(color: colors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xl,
                      ),
                      itemCount: items.length + (widget.allowNone ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          Divider(color: colors.line, height: 1),
                      itemBuilder: (context, index) {
                        if (widget.allowNone && index == 0) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '暂不指定雪场',
                              style: AppText.body.copyWith(color: colors.muted),
                            ),
                            onTap: () => Navigator.of(context).pop(''),
                          );
                        }
                        final name = items[index - (widget.allowNone ? 1 : 0)];
                        final active = name == widget.selected;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            name,
                            style: AppText.body.copyWith(
                              color: active ? colors.ink : colors.ink,
                            ),
                          ),
                          trailing: active
                              ? Icon(
                                  AppIcons.check,
                                  size: 18,
                                  color: colors.ink,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 苹果风格的日期时间轮盘：只允许「现在 ~ 一年后」。
Future<DateTime?> showDateTimeSheet(
  BuildContext context, {
  DateTime? initial,
  String title = '开始时间',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _DateTimeSheet(initial: initial, title: title),
  );
}

class _DateTimeSheet extends StatefulWidget {
  const _DateTimeSheet({required this.initial, required this.title});

  final DateTime? initial;
  final String title;

  @override
  State<_DateTimeSheet> createState() => _DateTimeSheetState();
}

class _DateTimeSheetState extends State<_DateTimeSheet> {
  late final DateTime _now = DateTime.now();
  late final List<DateTime> _days = _buildDays();
  late int _dayIndex;
  late int _hour;
  late int _minute;

  static const List<int> _minuteSteps = <int>[0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  List<DateTime> _buildDays() {
    final today = DateTime(_now.year, _now.month, _now.day);
    // 半年可选上限。
    return List<DateTime>.generate(
      183,
      (index) => today.add(Duration(days: index)),
    );
  }

  @override
  void initState() {
    super.initState();
    final seed = widget.initial ?? _now.add(const Duration(hours: 2));
    final safe = seed.isBefore(_now) ? _now.add(const Duration(hours: 1)) : seed;
    final day = DateTime(safe.year, safe.month, safe.day);
    final index = _days.indexWhere(
      (item) =>
          item.year == day.year && item.month == day.month && item.day == day.day,
    );
    _dayIndex = index < 0 ? 0 : index;
    _hour = safe.hour;
    _minute = ((safe.minute ~/ 5) * 5).clamp(0, 55);
  }

  DateTime get _value => DateTime(
    _days[_dayIndex].year,
    _days[_dayIndex].month,
    _days[_dayIndex].day,
    _hour,
    _minute,
  );

  bool get _isToday {
    final day = _days[_dayIndex];
    return day.year == _now.year &&
        day.month == _now.month &&
        day.day == _now.day;
  }

  /// 今天时只给出现在之后的小时，避免选出过去时间。
  List<int> get _hours =>
      _isToday
      ? List<int>.generate(24 - _now.hour, (index) => _now.hour + index)
      : List<int>.generate(24, (index) => index);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hours = _hours;
    if (!hours.contains(_hour)) _hour = hours.first;
    return SheetShell(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 216,
            child: Row(
              children: [
                // 年份只做展示，跟着日期滚轮走。
                SizedBox(
                  width: 68,
                  child: Center(
                    child: Text(
                      '${_days[_dayIndex].year}',
                      style: AppText.title.copyWith(color: colors.ink),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(
                      initialItem: _dayIndex,
                    ),
                    onSelectedItemChanged: (index) =>
                        setState(() => _dayIndex = index),
                    children: [
                      for (final day in _days)
                        Center(
                          child: Text(
                            '${day.month}月${day.day}日',
                            style: AppText.title.copyWith(color: colors.ink),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(
                      initialItem: hours.indexOf(_hour).clamp(0, hours.length - 1),
                    ),
                    onSelectedItemChanged: (index) =>
                        setState(() => _hour = hours[index]),
                    children: [
                      for (final hour in hours)
                        Center(
                          child: Text(
                            hour.toString().padLeft(2, '0'),
                            style: AppText.title.copyWith(color: colors.ink),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(
                      initialItem: _minuteSteps.indexOf(_minute).clamp(0, 11),
                    ),
                    onSelectedItemChanged: (index) =>
                        setState(() => _minute = _minuteSteps[index]),
                    children: [
                      for (final minute in _minuteSteps)
                        Center(
                          child: Text(
                            minute.toString().padLeft(2, '0'),
                            style: AppText.title.copyWith(color: colors.ink),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.md,
              AppSpace.xl,
              AppSpace.xl,
            ),
            child: AppButton(
              label: '完成',
              expand: true,
              onPressed: () {
                final value = _value;
                final now = DateTime.now();
                if (!value.isAfter(now)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请选择晚于现在的时间')),
                  );
                  return;
                }
                Navigator.of(context).pop(value);
              },
            ),
          ),
          Divider(color: colors.line, height: 1),
        ],
      ),
    );
  }
}

/// 约约约的「地点」筛选值：区县路径 + 雪场。
class ActivityPlaceFilter {
  const ActivityPlaceFilter({this.region = '', this.resort = ''});

  /// `河北·张家口·崇礼`，空表示不限。
  final String region;

  /// 雪场名，空表示该区县下全部雪场。
  final String resort;

  bool get isEmpty => region.isEmpty && resort.isEmpty;

  String get label {
    if (resort.isNotEmpty) return resort;
    if (region.isEmpty) return '全部地点';
    return regionLeaf(region);
  }
}

/// 两级地点筛选面板：左选区县，右选该区县下的雪场。
Future<ActivityPlaceFilter?> showActivityPlaceSheet(
  BuildContext context, {
  required ActivityPlaceFilter current,
}) {
  return showModalBottomSheet<ActivityPlaceFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlaceFilterSheet(current: current),
  );
}

class _PlaceFilterSheet extends StatefulWidget {
  const _PlaceFilterSheet({required this.current});

  final ActivityPlaceFilter current;

  @override
  State<_PlaceFilterSheet> createState() => _PlaceFilterSheetState();
}

class _PlaceFilterSheetState extends State<_PlaceFilterSheet> {
  late String _region = widget.current.region;
  late String _resort = widget.current.resort;

  List<GeoDistrictPath> get _districts => GeoRepository.instance.districtPaths;

  List<String> get _resorts {
    if (_region.isEmpty) return const <String>[];
    for (final item in _districts) {
      if (item.path == _region) return item.resorts;
    }
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SheetShell(
      title: '按地点筛选',
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Row(
          children: [
            SizedBox(
              width: 132,
              child: ListView(
                children: [
                  _PlaceTile(
                    label: '全部区县',
                    active: _region.isEmpty,
                    onTap: () => setState(() {
                      _region = '';
                      _resort = '';
                    }),
                  ),
                  for (final item in _districts)
                    _PlaceTile(
                      label: item.district,
                      active: item.path == _region,
                      onTap: () => setState(() {
                        _region = item.path;
                        _resort = '';
                      }),
                    ),
                ],
              ),
            ),
            VerticalDivider(color: colors.line, width: 1),
            Expanded(
              child: _region.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: Text(
                          '先选一个区县，再挑雪场',
                          textAlign: TextAlign.center,
                          style: AppText.bodySmall.copyWith(
                            color: colors.muted,
                          ),
                        ),
                      ),
                    )
                  : _resorts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: Text(
                          '这个区县还没有收录雪场',
                          textAlign: TextAlign.center,
                          style: AppText.bodySmall.copyWith(
                            color: colors.muted,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        _PlaceTile(
                          label: '全部雪场',
                          active: _resort.isEmpty,
                          onTap: () => setState(() => _resort = ''),
                        ),
                        for (final item in _resorts)
                          _PlaceTile(
                            label: item,
                            active: item == _resort,
                            onTap: () => setState(() => _resort = item),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
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
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        color: active ? colors.soft : Colors.transparent,
        child: Text(
          label,
          style: AppText.body.copyWith(
            color: active ? colors.ink : colors.muted,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 全部雪场名（去掉「暂无固定雪场」占位）。
List<String> resortOptionsFor(String regionPath) {
  final geo = GeoRepository.instance;
  final parts = regionPath
      .split('·')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (parts.length >= 3) {
    final province = geo.provinces.where((p) => p.name == parts[0]);
    if (province.isNotEmpty) {
      final city = province.first.city(parts[1]);
      final district = city?.district(parts[2]);
      if (district != null && district.resorts.isNotEmpty) {
        return district.resorts;
      }
    }
  }
  return geo.allResorts
      .where((item) => item != geo.noFixedResort)
      .toList(growable: false);
}
