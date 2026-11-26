import '../constants/geo.dart';

/// 把已存路径拆回省 / 市 / 区 / 县。
List<String> splitRegionPath(String? path) {
  final value = path?.trim() ?? '';
  if (value.isEmpty) return const <String>[];
  final geo = GeoRepository.instance;
  for (final province in geo.provinces) {
    if (value == province.name) return <String>[province.name];
    if (value.startsWith('${province.name}·')) {
      return value.split('·');
    }
  }
  return value.split('·');
}

/// 去掉「某某滑雪场」里的「滑雪场」后缀，只留场地名。
String shortResortName(String value) {
  var name = value.trim();
  for (final suffix in const <String>['滑雪场', '滑雪度假区', '滑雪胜地']) {
    if (name.length > suffix.length && name.endsWith(suffix)) {
      name = name.substring(0, name.length - suffix.length).trim();
      break;
    }
  }
  return name;
}

/// 取地区路径的最后一级（通常是区 / 县）。
String regionLeaf(String? path) {
  final parts = splitRegionPath(path);
  return parts.isEmpty ? '' : parts.last.trim();
}

/// 卡片、标签这类窄位置使用的短地区文案：`崇礼区·富龙`。
///
/// 雪场为「暂无固定雪场」或为空时只显示区县。
String shortRegionLabel({String? region, String? resort}) {
  final leaf = regionLeaf(region);
  final s = resort?.trim() ?? '';
  final shortResort = (s.isEmpty || s == GeoRepository.instance.noFixedResort)
      ? ''
      : shortResortName(s);
  final parts = <String>[
    if (leaf.isNotEmpty) leaf,
    if (shortResort.isNotEmpty) shortResort,
  ];
  return parts.join('·');
}
