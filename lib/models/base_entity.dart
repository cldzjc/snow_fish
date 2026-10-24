import 'package:equatable/equatable.dart';
import 'media_model.dart';

class BaseEntity extends Equatable {
  final String id;
  final String userId;
  final String entityType;
  final String title;
  final String? content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> extraData;
  final List<MediaModel> media;

  const BaseEntity({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.title,
    this.content,
    required this.createdAt,
    this.updatedAt,
    this.extraData = const {},
    this.media = const [],
  });

  /// 从数据库行创建 BaseEntity
  factory BaseEntity.fromJson(Map<String, dynamic> json) {
    final extraData = <String, dynamic>{};
    final rawExtraData = json['extra_data'];
    if (rawExtraData is Map) {
      extraData.addAll(rawExtraData.cast<String, dynamic>());
    }

    for (final key in [
      'audit_status',
      'sale_status',
      'stock_count',
      'sold_count',
      'review_note',
    ]) {
      if (json[key] != null && !extraData.containsKey(key)) {
        extraData[key] = json[key];
      }
    }

    return BaseEntity(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      entityType: json['entity_type'] ?? '',
      title: json['title'] ?? '',
      content: json['content'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      extraData: extraData,
      media:
          (json['media'] as List?)?.map((m) {
            final map = m is Map<String, dynamic> ? m : m as Map;
            return MediaModel.fromJson(map.cast<String, dynamic>());
          }).toList() ??
          [],
    );
  }

  /// 转换为 JSON（用于数据库操作）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'entity_type': entityType,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'extra_data': extraData,
    };
  }

  /// 获取 price（从 extraData 取）
  dynamic get price => extraData['price'];

  /// 获取 location（从 extraData 取）
  dynamic get location => extraData['location'];

  /// 向后兼容：卖家名称
  String get sellerName =>
      (extraData['seller_name'] as String?) ??
      (extraData['nickname'] as String?) ??
      '卖家';

  /// 向后兼容：卖家头像
  String get sellerAvatar =>
      (extraData['seller_avatar'] as String?) ??
      'https://picsum.photos/seed/avatar/80/80';

  /// 商品是否被卖家隐藏
  bool get isHidden => (extraData['is_hidden'] as bool?) ?? false;

  /// 条件等级（全新/九成新/八成新/七成新）
  String get conditionLevel =>
      (extraData['condition_level'] as String?) ?? '全新';

  /// 成交模式（面交优先/支持邮寄/两者均可）
  String get tradeMode => (extraData['trade_mode'] as String?) ?? '两者均可';

  /// 商品审核状态
  String get auditStatus =>
      (extraData['audit_status'] as String?) ?? 'approved';

  /// 向后兼容：销售状态（由 is_hidden 推导）
  String get saleStatus {
    if (isHidden) return 'hidden';
    if (auditStatus != 'approved') return 'pending_audit';
    return 'active';
  }

  /// 向后兼容：库存数量（C2C 固定单件）
  int get stockCount => 1;

  /// 向后兼容：成交数量
  int get soldCount => isHidden ? 1 : 0;

  /// 向后兼容：业务类型（纯 C2C）
  String get bizType => 'idle';

  /// 向后兼容：来源类型（纯 C2C）
  String get listingSource => 'idle';

  /// 向后兼容：审核范围
  String get auditScope => 'idle_product';

  /// 向后兼容：是否商家发布（纯 C2C 恒为 false）
  bool get isMerchantListing => false;

  /// 向后兼容：是否个人闲置（纯 C2C 恒为 true）
  bool get isPersonalIdle => true;

  /// 商品是否可购买：已审核 && 未隐藏 && 商品类型
  bool get isAvailable {
    if (entityType != 'product') return false;
    if (auditStatus != 'approved') return false;
    if (isHidden) return false;
    return true;
  }

  /// 是否可购买（同isAvailable）
  bool get isPurchasable => isAvailable;

  /// 创建副本，可选地覆盖某些字段
  BaseEntity copyWith({
    String? id,
    String? userId,
    String? entityType,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? extraData,
    List<MediaModel>? media,
  }) {
    return BaseEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraData: extraData ?? this.extraData,
      media: media ?? this.media,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    entityType,
    title,
    content,
    createdAt,
    updatedAt,
    extraData,
    media,
  ];
}
