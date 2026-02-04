import 'package:equatable/equatable.dart';

/// 评论数据模型
class CommentModel extends Equatable {
  final String id; // 评论ID (UUID)
  final String entityId; // 关联的帖子/商品ID
  final String userId; // 评论者ID
  final String content; // 评论内容
  final String? parentId; // 父评论ID（支持嵌套回复）
  final String? authorNickname; // 作者昵称（冗余存储用于快速显示）
  final String? authorAvatar; // 作者头像URL（冗余存储）
  final int likeCount; // 点赞数
  final bool userLiked; // 当前用户是否点赞（前端使用）
  final DateTime createdAt; // 创建时间
  final DateTime? updatedAt; // 更新时间
  final List<CommentModel> replies; // 回复列表（前端使用，初始为空）

  const CommentModel({
    required this.id,
    required this.entityId,
    required this.userId,
    required this.content,
    this.parentId,
    this.authorNickname,
    this.authorAvatar,
    this.likeCount = 0,
    this.userLiked = false,
    required this.createdAt,
    this.updatedAt,
    this.replies = const [],
  });

  /// 从JSON构造
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      entityId: json['entity_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      parentId: json['parent_id'] as String?,
      authorNickname: json['author_nickname'] as String?,
      authorAvatar: json['author_avatar'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      userLiked: json['user_liked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      replies: const [], // JSON中不包含回复，由前端构建
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'entity_id': entityId,
    'user_id': userId,
    'content': content,
    'parent_id': parentId,
    'author_nickname': authorNickname,
    'author_avatar': authorAvatar,
    'like_count': likeCount,
    'user_liked': userLiked,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// 复制并修改属性
  CommentModel copyWith({
    String? id,
    String? entityId,
    String? userId,
    String? content,
    String? parentId,
    String? authorNickname,
    String? authorAvatar,
    int? likeCount,
    bool? userLiked,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CommentModel>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      parentId: parentId ?? this.parentId,
      authorNickname: authorNickname ?? this.authorNickname,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      likeCount: likeCount ?? this.likeCount,
      userLiked: userLiked ?? this.userLiked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [
    id,
    entityId,
    userId,
    content,
    parentId,
    authorNickname,
    authorAvatar,
    likeCount,
    userLiked,
    createdAt,
    updatedAt,
    replies,
  ];
}
