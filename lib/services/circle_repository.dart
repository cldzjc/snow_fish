import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../constants/geo.dart';
import '../models/circle.dart';

/// 圈子数据。
///
/// 不单独维护一份圈子清单：直接从 `assets/data/geo.json` 派生，
/// 所以你在 geo.json 里加一个雪场，对应圈子就自动出现。
///
/// 如果需要改名 / 隐藏 / 排序，在 `assets/data/circles.json` 里覆盖，
/// 站点根目录放一份 `data/circles.json` 即可热更新（和 geo.json 同一机制）。
///
/// ```json
/// {
///   "hide": ["香港"],
///   "rename": { "崇礼": "崇礼雪区" },
///   "order": ["河北·张家口·崇礼", "北京·北京·密云"]
/// }
/// ```
class CircleRepository {
  CircleRepository._();

  static final CircleRepository instance = CircleRepository._();

  static const String assetPath = 'assets/data/circles.json';
  static const String remotePath = 'data/circles.json';

  final List<Circle> _districts = <Circle>[];
  final List<Circle> _resorts = <Circle>[];

  bool _loaded = false;

  final Set<String> _hidden = <String>{};
  final Map<String, String> _renamed = <String, String>{};
  final List<String> _order = <String>[];

  bool get isLoaded => _loaded;

  List<Circle> get districtCircles => List<Circle>.unmodifiable(_districts);

  /// 有雪场的区县圈（每个雪场一个雪场圈，每个有雪场的区县一个区县圈）。
  Future<void> load() async {
    if (_loaded) return;
    await GeoRepository.instance.load();
    _build();
    try {
      final raw = await rootBundle.loadString(assetPath);
      _applyOverrides(raw);
      _build();
    } catch (_) {
      // 没有覆盖文件时只按 geo.json 派生。
    }
    _loaded = true;
  }

  /// 站点上的覆盖文件（仅 Web，失败静默）。
  Future<void> refreshFromRemote() async {
    if (!kIsWeb) return;
    try {
      final uri = Uri.base.resolve(remotePath);
      if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return;
      }
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return;
      _applyOverrides(response.body);
      _build();
    } catch (_) {
      // 远端不存在时继续使用当前数据。
    }
  }

  void _applyOverrides(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;

    _hidden.clear();
    _renamed.clear();
    _order.clear();

    final hidden = decoded['hide'];
    if (hidden is List) {
      for (final item in hidden) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) _hidden.add(value);
      }
    }
    final rename = decoded['rename'];
    if (rename is Map) {
      rename.forEach((key, value) {
        final from = key?.toString().trim() ?? '';
        final to = value?.toString().trim() ?? '';
        if (from.isNotEmpty && to.isNotEmpty) _renamed[from] = to;
      });
    }
    final order = decoded['order'];
    if (order is List) {
      for (final item in order) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) _order.add(value);
      }
    }
  }

  void _build() {
    _districts.clear();
    _resorts.clear();

    for (final province in GeoRepository.instance.provinces) {
      for (final city in province.cities) {
        for (final district in city.districts) {
          final resorts = district.resorts
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
          if (resorts.isEmpty) continue;

          final regionPath = GeoRepository.joinPath(
            province.name,
            city.name,
            district.name,
          );
          if (_isHidden(regionPath) || _isHidden(district.name)) continue;

          final districtCircle = Circle(
            id: regionPath,
            name: _displayName(district.name),
            region: regionPath,
          );
          _districts.add(districtCircle);

          for (final resort in resorts) {
            _resorts.add(
              Circle(
                id: '$regionPath/$resort',
                name: _displayName(resort),
                region: regionPath,
                resort: resort,
                parentId: regionPath,
              ),
            );
          }
        }
      }
    }

    if (_order.isNotEmpty) {
      int rank(Circle circle) {
        final index = _order.indexOf(circle.region);
        return index < 0 ? _order.length : index;
      }

      _districts.sort((a, b) => rank(a).compareTo(rank(b)));
    }
  }

  bool _isHidden(String key) => _hidden.contains(key);

  String _displayName(String name) => _renamed[name] ?? name;

  /// 全部区县圈，按 override 里的 order 优先。
  List<Circle> get districts {
    if (_order.isEmpty) {
      final sorted = List<Circle>.from(_districts)
        ..sort((a, b) => a.name.compareTo(b.name));
      return List<Circle>.unmodifiable(sorted);
    }
    return List<Circle>.unmodifiable(_districts);
  }

  /// 某个区县圈下的雪场圈。
  List<Circle> resortsOf(String districtId) {
    final items = _resorts.where((item) => item.parentId == districtId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List<Circle>.unmodifiable(items);
  }

  Circle? byId(String? id) {
    final value = id?.trim() ?? '';
    if (value.isEmpty) return null;
    for (final item in _districts) {
      if (item.id == value) return item;
    }
    for (final item in _resorts) {
      if (item.id == value) return item;
    }
    return null;
  }

  /// 按「地区 + 雪场」定位圈子；雪场找不到时退回区县圈。
  Circle? forSelection(String? region, String? resort) {
    final regionPath = region?.trim() ?? '';
    if (regionPath.isEmpty) return null;
    final resortName = resort?.trim() ?? '';
    if (resortName.isNotEmpty &&
        resortName != GeoRepository.instance.noFixedResort) {
      final id = '$regionPath/$resortName';
      for (final item in _resorts) {
        if (item.id == id) return item;
      }
    }
    for (final item in _districts) {
      if (item.id == regionPath) return item;
    }
    return null;
  }

  /// 用户入圈信息 → 圈子对象。
  CircleMembership? membershipFrom({
    String? region,
    String? resort,
    DateTime? joinedAt,
    DateTime? lockedUntil,
  }) {
    final district = forSelection(region, null);
    if (district == null) return null;
    final resortCircle = forSelection(region, resort);
    return CircleMembership(
      district: district,
      resort: resortCircle != null && resortCircle.isResortCircle
          ? resortCircle
          : null,
      joinedAt: joinedAt,
      lockedUntil: lockedUntil,
    );
  }

  /// 某个圈子在查询时要包含的 circle_id 集合。
  ///
  /// 区县圈会把旗下所有雪场圈一起带上，实现「崇礼圈能看到富龙、万龙的帖子」。
  List<String> scopeIds(Circle circle) {
    if (!circle.isResortCircle) {
      final children = _resorts
          .where((item) => item.parentId == circle.id)
          .map((item) => item.id);
      return <String>[circle.id, ...children];
    }
    return <String>[circle.id];
  }

  /// 帖子上的 circle_id → 展示用的圈子标签。
  String? tagFor(String? circleId) => byId(circleId)?.postTag;
}
