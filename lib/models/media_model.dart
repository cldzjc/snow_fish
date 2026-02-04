import 'package:equatable/equatable.dart';

class MediaModel extends Equatable {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String mediaType;
  final int sortOrder;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const MediaModel({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.mediaType,
    this.sortOrder = 0,
    this.metadata,
    required this.createdAt,
  });

  /// 从 JSON 创建 MediaModel
  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      mediaType: json['media_type'] ?? 'image',
      sortOrder: json['sort_order'] ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'media_type': mediaType,
      'sort_order': sortOrder,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    url,
    thumbnailUrl,
    mediaType,
    sortOrder,
    metadata,
    createdAt,
  ];
}
