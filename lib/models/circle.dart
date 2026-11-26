/// 圈子。
///
/// 由地区数据自动派生，两级：
/// - 区县圈：`河北·张家口·崇礼`，包含该区县下所有雪场的帖子；
/// - 雪场圈：`河北·张家口·崇礼/富龙`，只包含该雪场的帖子。
///
/// [id] 直接由地区路径拼出来，所以不需要额外的表来维护圈子。
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.region,
    this.resort,
    this.parentId,
  });

  /// 区县圈用地区路径；雪场圈用「地区路径/雪场」。
  final String id;

  /// 只有地名，展示时补一个「圈」字，例如「崇礼圈」。
  final String name;

  /// 完整地区路径，例如 `河北·张家口·崇礼`。
  final String region;

  /// 雪场名；区县圈为 null。
  final String? resort;

  /// 雪场圈所属的区县圈 id。
  final String? parentId;

  bool get isResortCircle => resort != null && resort!.trim().isNotEmpty;

  String get label => '$name圈';

  /// 圈内帖子卡片右上角展示的标签。
  String get postTag => label;

  @override
  bool operator ==(Object other) => other is Circle && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Circle($id)';
}

/// 用户已加入的圈子：区县圈 + 可选雪场圈。
class CircleMembership {
  const CircleMembership({
    required this.district,
    this.resort,
    this.joinedAt,
    this.lockedUntil,
  });

  final Circle district;

  /// 用户同时选定的雪场圈；没选时为 null。
  final Circle? resort;

  final DateTime? joinedAt;

  /// 换圈解锁时间；为空表示没有限制。
  final DateTime? lockedUntil;

  String get region => district.region;

  String? get resortName => resort?.resort;

  /// 入圈时选定的、用于发帖归属的圈：优先雪场圈。
  Circle get primary => resort ?? district;

  /// 当前展示的圈子名，例如「崇礼圈」。
  String get label => district.label;

  /// 「崇礼 · 富龙」这样的完整描述。
  String get fullLabel =>
      resort == null ? district.label : '${district.name} · ${resort!.label}';

  /// 现在是否还在 30 天锁定期内。
  bool isLockedAt(DateTime now) {
    final until = lockedUntil;
    return until != null && now.isBefore(until);
  }

  /// 距离可以换圈还剩几天；已解锁或没有限制时返回 0。
  int remainingLockDaysAt(DateTime now) {
    final until = lockedUntil;
    if (until == null) return 0;
    final diff = until.difference(now);
    if (diff.inMilliseconds <= 0) return 0;
    return diff.inHours <= 0 ? 1 : (diff.inHours / 24).ceil();
  }
}
