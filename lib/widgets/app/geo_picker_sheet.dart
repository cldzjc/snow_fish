import 'package:flutter/material.dart';

import '../../constants/geo.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/geo_format.dart';
import 'app_button.dart';
import 'app_icons.dart';

export '../../utils/geo_format.dart'
    show splitRegionPath, shortResortName, regionLeaf, shortRegionLabel;

/// 选择结果：省 / 市 / 区路径 + 雪场。
class GeoSelection {
  const GeoSelection({required this.region, required this.resort});

  /// 形如 `河北·张家口·崇礼`。
  final String region;

  /// 雪场名，未选定时为「暂无固定雪场」。
  final String resort;

  String get display {
    if (resort.isEmpty || resort == GeoRepository.instance.noFixedResort) {
      return region;
    }
    return '$region · $resort';
  }
}

/// 打开级联地区选择面板（左栏分类 + 右侧选项）。
Future<GeoSelection?> showGeoPicker(
  BuildContext context, {
  required String title,
  String? initialRegion,
  String? initialResort,
}) {
  return showModalBottomSheet<GeoSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GeoPickerSheet(
      title: title,
      initialRegion: initialRegion,
      initialResort: initialResort,
    ),
  );
}

/// 表单里的「常驻地区」字段：显示当前值，点击打开级联选择。
class RegionField extends StatelessWidget {
  const RegionField({
    super.key,
    required this.region,
    required this.resort,
    required this.onChanged,
  });

  final String region;
  final String resort;
  final ValueChanged<GeoSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final geo = GeoRepository.instance;
    final parts = <String>[
      if (region.trim().isNotEmpty) region.trim(),
      if (resort.trim().isNotEmpty && resort.trim() != geo.noFixedResort)
        shortResortName(resort),
    ];
    final label = parts.isEmpty ? '选择省份 / 城市 / 区县' : parts.join('·');

    return Semantics(
      button: true,
      label: '选择常驻地区',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () async {
          final selection = await showGeoPicker(
            context,
            title: '常驻地区',
            initialRegion: region,
            initialResort: resort,
          );
          if (selection != null) onChanged(selection);
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: parts.isEmpty ? colors.muted : colors.ink,
                  ),
                ),
              ),
              Icon(AppIcons.chevron, size: 18, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

enum _GeoStep { province, city, district, resort }

class _GeoPickerSheet extends StatefulWidget {
  const _GeoPickerSheet({
    required this.title,
    this.initialRegion,
    this.initialResort,
  });

  final String title;
  final String? initialRegion;
  final String? initialResort;

  @override
  State<_GeoPickerSheet> createState() => _GeoPickerSheetState();
}

class _GeoPickerSheetState extends State<_GeoPickerSheet> {
  final GeoRepository _geo = GeoRepository.instance;

  String _province = '';
  String _city = '';
  String _district = '';
  String _resort = '';
  _GeoStep _step = _GeoStep.province;

  @override
  void initState() {
    super.initState();
    final parts = splitRegionPath(widget.initialRegion);
    if (parts.isNotEmpty) _province = parts[0];
    if (parts.length > 1) _city = parts[1];
    if (parts.length > 2) _district = parts[2];
    _resort = (widget.initialResort ?? '').trim();
    if (_resort.isEmpty) _resort = _geo.noFixedResort;
    // 有历史值时从最后一级开始看，方便直接改。
    if (_district.isNotEmpty) {
      _step = _GeoStep.resort;
    } else if (_city.isNotEmpty) {
      _step = _GeoStep.district;
    } else if (_province.isNotEmpty) {
      _step = _GeoStep.city;
    }
  }

  GeoProvince? get _currentProvince {
    for (final item in _geo.provinces) {
      if (item.name == _province) return item;
    }
    return null;
  }

  GeoCity? get _currentCity => _currentProvince?.city(_city);

  GeoDistrict? get _currentDistrict => _currentCity?.district(_district);

  List<String> _optionsOf(_GeoStep step) {
    switch (step) {
      case _GeoStep.province:
        return _geo.provinceNames;
      case _GeoStep.city:
        return _currentProvince?.cityNames ?? const <String>[];
      case _GeoStep.district:
        return _currentCity?.districtNames ?? const <String>[];
      case _GeoStep.resort:
        final resorts = _currentDistrict?.resorts ?? const <String>[];
        return <String>[_geo.noFixedResort, ...resorts];
    }
  }

  String _valueOf(_GeoStep step) {
    switch (step) {
      case _GeoStep.province:
        return _province;
      case _GeoStep.city:
        return _city;
      case _GeoStep.district:
        return _district;
      case _GeoStep.resort:
        return _resort;
    }
  }

  void _select(_GeoStep step, String value) {
    setState(() {
      switch (step) {
        case _GeoStep.province:
          _province = value;
          _city = '';
          _district = '';
          _resort = _geo.noFixedResort;
          _step = _GeoStep.city;
        case _GeoStep.city:
          _city = value;
          _district = '';
          _resort = _geo.noFixedResort;
          _step = _GeoStep.district;
        case _GeoStep.district:
          _district = value;
          _resort = _geo.noFixedResort;
          _step = _GeoStep.resort;
        case _GeoStep.resort:
          _resort = value;
      }
    });
    // 下一级还有内容就自动推进，否则停在当前让用户确认。
    final next = _nextStep(step);
    if (next != null && _optionsOf(next).isNotEmpty) {
      setState(() => _step = next);
    }
  }

  _GeoStep? _nextStep(_GeoStep step) {
    switch (step) {
      case _GeoStep.province:
        return _GeoStep.city;
      case _GeoStep.city:
        return _GeoStep.district;
      case _GeoStep.district:
        return _GeoStep.resort;
      case _GeoStep.resort:
        return null;
    }
  }

  String _label(_GeoStep step) {
    switch (step) {
      case _GeoStep.province:
        return '省份';
      case _GeoStep.city:
        return '城市';
      case _GeoStep.district:
        return '区县';
      case _GeoStep.resort:
        return '雪场';
    }
  }

  String _summary(_GeoStep step) {
    final value = _valueOf(step);
    if (value.isEmpty) return '请选择';
    return step == _GeoStep.resort ? shortResortName(value) : value;
  }

  bool get _canConfirm => _province.isNotEmpty && _district.isNotEmpty;

  String get _preview {
    final region = GeoRepository.joinPath(_province, _city, _district);
    return GeoSelection(region: region, resort: _resort).display;
  }

  void _clear() {
    setState(() {
      _province = '';
      _city = '';
      _district = '';
      _resort = _geo.noFixedResort;
      _step = _GeoStep.province;
    });
  }

  void _confirm() {
    final region = GeoRepository.joinPath(_province, _city, _district);
    Navigator.of(context).pop(GeoSelection(region: region, resort: _resort));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final options = _optionsOf(_step);
    final selected = _valueOf(_step);
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 顶部拖拽条 + 标题
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
                    child: Text(
                      widget.title,
                      style: AppText.pageTitle.copyWith(color: colors.ink),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '关闭',
                    child: InkWell(
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
                        child: Icon(
                          AppIcons.close,
                          size: 17,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.line),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRail(colors),
                  VerticalDivider(width: 1, color: colors.line),
                  Expanded(
                    child: options.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpace.xl),
                              child: Text(
                                '上一级还没有可选内容，先选上一级吧',
                                textAlign: TextAlign.center,
                                style: AppText.bodySmall.copyWith(
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options[index];
                              final active = option == selected;
                              final text = _step == _GeoStep.resort
                                  ? shortResortName(option)
                                  : option;
                              return _OptionRow(
                                label: text,
                                active: active,
                                isResort: _step == _GeoStep.resort,
                                onTap: () => _select(_step, option),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.line),
            // 底部固定操作区，永远在屏幕内
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
                AppSpace.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.place, size: 14, color: colors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _canConfirm ? _preview : '至少选择到区县',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySmall.copyWith(
                            color: _canConfirm ? colors.ink : colors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _canConfirm ? _clear : null,
                        child: Text(
                          '清除',
                          style: AppText.button.copyWith(color: colors.muted),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: AppButton(
                          label: '确定',
                          expand: true,
                          onPressed: _canConfirm ? _confirm : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(AppColors colors) {
    return SizedBox(
      width: 104,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (final step in _GeoStep.values)
            _RailTile(
              label: _label(step),
              value: _summary(step),
              active: _step == step,
              onTap: () => setState(() => _step = step),
            ),
        ],
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          8,
          AppSpace.md,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: active ? colors.ink : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.bodySmall.copyWith(
                color: active ? colors.ink : colors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: active
                    ? colors.ink
                    : colors.muted.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.active,
    required this.isResort,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool isResort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: active
                  ? Icon(AppIcons.check, size: 17, color: colors.ink)
                  : Icon(AppIcons.chevron, size: 15, color: colors.line),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: colors.ink,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
