import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String? nickname;
  final String? avatarUrl;
  final String? backgroundUrl;
  final String? bio;
  final String? residentRegion;
  final String? residentResort;
  final String role;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.nickname,
    this.avatarUrl,
    this.backgroundUrl,
    this.bio,
    this.residentRegion,
    this.residentResort,
    this.role = 'user',
    required this.updatedAt,
  });

  /// 从 JSON 创建 UserProfile
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      backgroundUrl: json['background_url'],
      bio: json['bio'],
      residentRegion: json['resident_region'],
      residentResort: json['resident_resort'],
      role:
          (json['role'] as String?) ?? (json['user_role'] as String?) ?? 'user',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  /// 转换为 JSON（用于数据库操作）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'background_url': backgroundUrl,
      'bio': bio,
      'resident_region': residentRegion,
      'resident_resort': residentResort,
      'role': role,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 创建副本，可选地覆盖某些字段
  UserProfile copyWith({
    String? id,
    String? nickname,
    String? avatarUrl,
    String? backgroundUrl,
    String? bio,
    String? residentRegion,
    String? residentResort,
    String? role,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      bio: bio ?? this.bio,
      residentRegion: residentRegion ?? this.residentRegion,
      residentResort: residentResort ?? this.residentResort,
      role: role ?? this.role,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    nickname,
    avatarUrl,
    backgroundUrl,
    bio,
    residentRegion,
    residentResort,
    role,
    updatedAt,
  ];
}
