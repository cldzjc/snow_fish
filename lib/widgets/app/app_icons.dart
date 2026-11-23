import 'package:flutter/material.dart';

/// 统一的线性图标集。
///
/// 全部使用 Material 的 outlined 变体，保持细描边与一致的视觉重量，
/// 页面里不再直接写 Icons.xxx，换图标只改这里。
class AppIcons {
  const AppIcons._();

  // 底部导航
  static const IconData home = Icons.home_outlined;
  static const IconData homeFilled = Icons.home_rounded;
  static const IconData mail = Icons.mail_outline_rounded;
  static const IconData plus = Icons.add_rounded;
  static const IconData bell = Icons.notifications_none_rounded;
  static const IconData person = Icons.person_outline_rounded;

  // 内容操作
  static const IconData heart = Icons.favorite_border_rounded;
  static const IconData heartFilled = Icons.favorite_rounded;
  static const IconData comment = Icons.mode_comment_outlined;
  static const IconData bookmark = Icons.bookmark_border_rounded;
  static const IconData bookmarkFilled = Icons.bookmark_rounded;
  static const IconData flag = Icons.flag_outlined;
  static const IconData share = Icons.send_outlined;

  // 导航与通用
  static const IconData back = Icons.chevron_left_rounded;
  static const IconData chevron = Icons.chevron_right_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData alert = Icons.error_outline_rounded;
  static const IconData refresh = Icons.refresh_rounded;

  // 内容类型
  static const IconData image = Icons.image_outlined;
  static const IconData video = Icons.videocam_outlined;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData mountain = Icons.landscape_outlined;
  static const IconData ski = Icons.downhill_skiing;
  static const IconData camera = Icons.photo_camera_outlined;
  static const IconData food = Icons.restaurant_outlined;
  static const IconData gear = Icons.backpack_outlined;
  static const IconData edit = Icons.edit_outlined;
  static const IconData trash = Icons.delete_outline_rounded;
  static const IconData group = Icons.group_add_outlined;
  static const IconData block = Icons.block_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData shield = Icons.shield_outlined;
  static const IconData settings = Icons.tune_rounded;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData calendar = Icons.event_outlined;
  static const IconData place = Icons.place_outlined;
}

/// 活动类型 → 图标。
IconData activityIcon(String entityType) {
  return switch (entityType) {
    'activity_ski' => AppIcons.ski,
    'activity_photo' => AppIcons.camera,
    'activity_food' => AppIcons.food,
    'activity_gear' => AppIcons.gear,
    _ => AppIcons.mountain,
  };
}
