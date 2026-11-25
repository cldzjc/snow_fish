import 'package:flutter/material.dart';

import '../../constants/geo.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';
import 'app_field.dart';
import 'app_icons.dart';
import 'app_sheet.dart';

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

/// 打开级联地区选择面板。
Future<GeoSelection?> showGeoPicker(
  BuildContext context, {
  required String title,
  String? initialRegion,
  String? initialResort,
}) {
  return showAppSheet<GeoSelection>(
    context,
    title: title,
    builder: (_) => _GeoPickerBody(
      initialRegion: initialRegion,
      initialResort: initialResort,
    ),
  );
}

/// 把已存路径拆回省 / 市 / 区。
List<String> splitRegionPath(String? path) {
  final value = path?.trim() ?? '';
  final geo = GeoRepository.instance;
  if (value.isEmpty) return const <String>[];
  // 省份内部本身带「·」的情况（例如「北京·北京」）按实际数据切分。
  for (final province in geo.provinces) {
    if (value == province.name) return <String>[province.name];
    if (value.startsWith('${province.name}·')) {
      return value.split('·');
    }
  }
  return value.split('·');
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
        resort.trim(),
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

class _GeoPickerBody extends StatefulWidget {
  const _GeoPickerBody({this.initialRegion, this.initialResort});

  final String? initialRegion;
  final String? initialResort;

  @override
  State<_GeoPickerBody> createState() => _GeoPickerBodyState();
}

class _GeoPickerBodyState extends State<_GeoPickerBody> {
  final GeoRepository _geo = GeoRepository.instance;

  String _province = '';
  String _city = '';
  String _district = '';
  String _resort = '';

  @override
  void initState() {
    super.initState();
    final parts = splitRegionPath(widget.initialRegion);
    if (parts.isNotEmpty) _province = parts[0];
    if (parts.length > 1) _city = parts[1];
    if (parts.length > 2) _district = parts[2];
    _resort = (widget.initialResort ?? '').trim();
    if (_resort.isEmpty) _resort = _geo.noFixedResort;
  }

  GeoProvince? get _currentProvince {
    for (final item in _geo.provinces) {
      if (item.name == _province) return item;
    }
    return null;
  }

  GeoCity? get _currentCity => _currentProvince?.city(_city);

  GeoDistrict? get _currentDistrict => _currentCity?.district(_district);

  List<String> get _districts => _currentCity?.districtNames ?? const [];

  List<String> get _resortOptions {
    final resorts = _currentDistrict?.resorts ?? const <String>[];
    return <String>[_geo.noFixedResort, ...resorts];
  }

  bool get _canConfirm => _province.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provinceOptions = _geo.provinces
        .map((item) => AppOption<String>(item.name, item.name))
        .toList();
    final cityOptions = (_currentProvince?.cityNames ?? const <String>[])
        .map((item) => AppOption<String>(item, item))
        .toList();
    final districtOptions = _districts
        .map((item) => AppOption<String>(item, item))
        .toList();
    final resortOptions = _resortOptions
        .map((item) => AppOption<String>(item, item))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppField(
          label: '省份',
          requiredMark: true,
          child: AppDropdown<String>(
            options: provinceOptions,
            value: _province.isEmpty ? null : _province,
            hint: '请选择省份',
            onChanged: (value) => setState(() {
              _province = value ?? '';
              _city = '';
              _district = '';
              _resort = _geo.noFixedResort;
            }),
          ),
        ),
        if (cityOptions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          AppField(
            label: '城市',
            child: AppDropdown<String>(
              options: cityOptions,
              value: _city.isEmpty ? null : _city,
              hint: '请选择城市',
              onChanged: (value) => setState(() {
                _city = value ?? '';
                _district = '';
                _resort = _geo.noFixedResort;
              }),
            ),
          ),
        ],
        if (districtOptions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          AppField(
            label: '区县',
            child: AppDropdown<String>(
              options: districtOptions,
              value: _district.isEmpty ? null : _district,
              hint: '请选择区县',
              onChanged: (value) => setState(() {
                _district = value ?? '';
                _resort = _geo.noFixedResort;
              }),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        AppField(
          label: '常驻雪场',
          note: '没有固定雪场就选「${_geo.noFixedResort}」',
          child: AppDropdown<String>(
            options: resortOptions,
            value: _resortOptions.contains(_resort)
                ? _resort
                : _geo.noFixedResort,
            onChanged: (value) =>
                setState(() => _resort = value ?? _geo.noFixedResort),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          _canConfirm ? '将保存为：${_preview()}' : '至少需要选择省份，地区是你在社区里的身份标签。',
          style: AppText.caption.copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          label: '确定',
          expand: true,
          onPressed: _canConfirm ? _confirm : null,
        ),
      ],
    );
  }

  String _preview() {
    final region = GeoRepository.joinPath(_province, _city, _district);
    return GeoSelection(region: region, resort: _resort).display;
  }

  void _confirm() {
    final region = GeoRepository.joinPath(_province, _city, _district);
    Navigator.of(context).pop(GeoSelection(region: region, resort: _resort));
  }
}
