import 'package:flutter/material.dart';

/// 字号与字重层级。
///
/// 颜色由调用方通过 `copyWith(color: ...)` 注入，
/// 这样同一套层级可同时用于亮色与暗色。
class AppText {
  const AppText._();

  /// 顶部字标 skneo.
  static const TextStyle brand = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.1,
  );

  /// 页面主标题（发布入口、活动类型选择这类整页标题）。
  static const TextStyle display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.35,
  );

  /// 顶部栏标题。
  static const TextStyle pageTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 列表标题。
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  /// 正文。
  static const TextStyle body = TextStyle(fontSize: 16, height: 1.55);

  /// 次级正文。
  static const TextStyle bodySmall = TextStyle(fontSize: 14, height: 1.5);

  /// 元信息（时间、地区）。
  static const TextStyle meta = TextStyle(fontSize: 13, height: 1.4);

  /// 最小号说明。
  static const TextStyle caption = TextStyle(fontSize: 12, height: 1.4);

  /// 表单字段名。
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 按钮文案。
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Tab 文案。
  static const TextStyle tab = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}
