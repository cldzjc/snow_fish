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
      extraData: (json['extra_data'] as Map<String, dynamic>?) ?? {},
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
