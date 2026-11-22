import 'package:flutter/material.dart';

/// 设计令牌：亮/暗两套语义色。
///
/// 命名对应界面用途，不直接写颜色值，避免页面里散落十六进制。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.soft,
    required this.ink,
    required this.muted,
    required this.line,
    required this.danger,
  });

  /// 页面底色、输入框底。
  final Color paper;

  /// 次级块、骨架屏、标签底。
  final Color soft;

  /// 主文字、实心按钮底色。
  final Color ink;

  /// 次级文字、元信息。
  final Color muted;

  /// 分割线、描边。
  final Color line;

  /// 点赞、删除等语义红。
  final Color danger;

  static const AppColors light = AppColors(
    paper: Color(0xFFFFFFFF),
    soft: Color(0xFFF5F5F5),
    ink: Color(0xFF171717),
    muted: Color(0xFF737373),
    line: Color(0xFFEAEAEA),
    danger: Color(0xFFC8374B),
  );

  static const AppColors dark = AppColors(
    paper: Color(0xFF101010),
    soft: Color(0xFF242424),
    ink: Color(0xFFF5F5F5),
    muted: Color(0xFFABABAB),
    line: Color(0xFF2B2B2B),
    danger: Color(0xFFE0576B),
  );

  @override
  AppColors copyWith({
    Color? paper,
    Color? soft,
    Color? ink,
    Color? muted,
    Color? line,
    Color? danger,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      soft: soft ?? this.soft,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
