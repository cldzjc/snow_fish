import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// 省 / 市 / 区县 / 雪场 四级地区数据。
///
/// 数据源是 `assets/data/geo.json`，格式见该文件；改完重新构建即可生效。
/// 如果站点根目录放了 `data/geo.json`，启动时会优先采用它，
/// 这样上传一个新文件、刷新页面就能更新，不必重新编译 Flutter。
class GeoRepository {
  GeoRepository._();

  static final GeoRepository instance = GeoRepository._();

  static const String assetPath = 'assets/data/geo.json';

  /// 站点上的可覆盖文件（相对站点根目录）。
  static const String remotePath = 'data/geo.json';

  /// 没有固定雪场时使用的占位值。
  String noFixedResort = '暂无固定雪场';

  List<GeoProvince> provinces = const <GeoProvince>[];

  String version = '';

  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// 启动时调用一次。失败时保持空数据，不阻塞应用。
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(assetPath);
      _apply(raw);
    } catch (error) {
      debugPrint('地区数据读取失败: $error');
    }
    _loaded = true;
  }

  /// 后台尝试用站点上的同名文件覆盖内置数据（仅 Web，失败静默）。
  Future<void> refreshFromRemote() async {
    if (!kIsWeb) return;
    try {
      final uri = Uri.base.resolve(remotePath);
      if (!uri.hasScheme || !uri.isScheme('http') && !uri.isScheme('https')) {
        return;
      }
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return;
      _apply(response.body);
    } catch (_) {
      // 远端不存在或网络失败时继续使用内置数据。
    }
  }

  void _apply(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    final nextNoFixed = (decoded['noFixedResort'] as String?)?.trim();
    if (nextNoFixed != null && nextNoFixed.isNotEmpty) {
      noFixedResort = nextNoFixed;
    }
    final list = decoded['regions'];
    if (list is! List) return;
    final parsed = <GeoProvince>[];
    for (final item in list) {
      if (item is! Map) continue;
      final name = (item['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final cities = <GeoCity>[];
      final rawCities = item['cities'];
      if (rawCities is List) {
        for (final city in rawCities) {
          if (city is! Map) continue;
          final cityName = (city['name'] as String?)?.trim() ?? '';
          if (cityName.isEmpty) continue;
          final districts = <GeoDistrict>[];
          final rawDistricts = city['districts'];
          if (rawDistricts is List) {
            for (final district in rawDistricts) {
              if (district is! Map) continue;
              final districtName = (district['name'] as String?)?.trim() ?? '';
              if (districtName.isEmpty) continue;
              final resorts = <String>[];
              final rawResorts = district['resorts'];
              if (rawResorts is List) {
                for (final resort in rawResorts) {
                  final value = resort?.toString().trim() ?? '';
                  if (value.isNotEmpty) resorts.add(value);
                }
              }
              districts.add(GeoDistrict(name: districtName, resorts: resorts));
            }
          }
          cities.add(GeoCity(name: cityName, districts: districts));
        }
      }
      parsed.add(GeoProvince(name: name, cities: cities));
    }
    if (parsed.isEmpty) return;
    provinces = List<GeoProvince>.unmodifiable(parsed);
    version = (decoded['version'] as String?)?.trim() ?? '';
  }

  /// 省份名列表（活动筛选、旧数据兼容用）。
  List<String> get provinceNames =>
      provinces.map((item) => item.name).toList(growable: false);

  /// 全部雪场名（扁平，含「暂无固定雪场」）。
  List<String> get allResorts {
    final seen = <String>{noFixedResort};
    for (final province in provinces) {
      for (final city in province.cities) {
        for (final district in city.districts) {
          seen.addAll(district.resorts);
        }
      }
    }
    return seen.toList(growable: false);
  }

  /// 从「省·市·区」路径里取省份，用于活动筛选。
  String provinceOf(String? regionPath) {
    final value = regionPath?.trim() ?? '';
    if (value.isEmpty) return '';
    final head = value.split('·').first.trim();
    return provinceNames.contains(head) ? head : '';
  }

  /// 雪场名 → 所在区县路径（`河北·张家口·崇礼`）。
  String? districtPathOfResort(String? resort) {
    final name = resort?.trim() ?? '';
    if (name.isEmpty || name == noFixedResort) return null;
    for (final province in provinces) {
      for (final city in province.cities) {
        for (final district in city.districts) {
          if (district.resorts.contains(name)) {
            return joinPath(province.name, city.name, district.name);
          }
        }
      }
    }
    return null;
  }

  /// 扁平化的区县列表（带上级路径），供约约约两级筛选使用。
  List<GeoDistrictPath> get districtPaths {
    final result = <GeoDistrictPath>[];
    for (final province in provinces) {
      for (final city in province.cities) {
        for (final district in city.districts) {
          result.add(
            GeoDistrictPath(
              path: joinPath(province.name, city.name, district.name),
              district: district.name,
              resorts: district.resorts,
            ),
          );
        }
      }
    }
    return result;
  }

  /// 把三级行政区拼成存储路径。
  static String joinPath(String province, String city, String district) {
    return <String>[
      province.trim(),
      city.trim(),
      district.trim(),
    ].where((item) => item.isNotEmpty).join('·');
  }
}

class GeoProvince {
  const GeoProvince({required this.name, required this.cities});

  final String name;
  final List<GeoCity> cities;

  List<String> get cityNames =>
      cities.map((item) => item.name).toList(growable: false);

  GeoCity? city(String name) {
    for (final item in cities) {
      if (item.name == name) return item;
    }
    return null;
  }
}

class GeoCity {
  const GeoCity({required this.name, required this.districts});

  final String name;
  final List<GeoDistrict> districts;

  List<String> get districtNames =>
      districts.map((item) => item.name).toList(growable: false);

  GeoDistrict? district(String name) {
    for (final item in districts) {
      if (item.name == name) return item;
    }
    return null;
  }
}

class GeoDistrict {
  const GeoDistrict({required this.name, required this.resorts});

  final String name;
  final List<String> resorts;
}

/// 带上级路径的区县，用于「地点」两级筛选。
class GeoDistrictPath {
  const GeoDistrictPath({
    required this.path,
    required this.district,
    required this.resorts,
  });

  /// `河北·张家口·崇礼`
  final String path;

  /// `崇礼`
  final String district;

  final List<String> resorts;
}

/// 兼容旧调用点的门面。
///
/// 新代码请直接用 [GeoRepository.instance]。
class GeoData {
  const GeoData._();

  static List<String> get provinces => GeoRepository.instance.provinceNames;

  static String get noFixedResort => GeoRepository.instance.noFixedResort;

  static List<String> get resorts => GeoRepository.instance.allResorts;
}
