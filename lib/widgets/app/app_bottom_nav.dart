import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_icons.dart';

/// 底部导航：5 个入口，中间「发布」是动作。
///
/// [selected] 用导航槽位（0 首页 / 1 私信 / 3 通知 / 4 我的），
/// 发布不占选中态，传 -1 表示当前没有选中项。
///
/// 视觉：悬浮磨砂胶囊 + 无文字标签 + 平滑移动的选中块。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selected,
    required this.onSelect,
    this.unread = 0,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final int unread;

  static const int _itemCount = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.sm,
        AppSpace.xl,
        AppSpace.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              // 半透明底 + 背景模糊：能看见内容，但图标依然清晰。
              color: colors.paper.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.line.withValues(alpha: 0.7)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth = constraints.maxWidth / _itemCount;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      left: selected < 0
                          ? slotWidth * 4.5
                          : slotWidth * selected,
                      top: 5,
                      width: slotWidth,
                      height: constraints.maxHeight - 10,
                      child: AnimatedOpacity(
                        opacity: selected < 0 ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: Center(
                          child: Container(
                            width: slotWidth - 12,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: colors.ink.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _NavItem(
                          icon: AppIcons.home,
                          activeIcon: AppIcons.homeFilled,
                          label: '首页',
                          active: selected == 0,
                          onTap: () => onSelect(0),
                        ),
                        _NavItem(
                          icon: AppIcons.mail,
                          label: '私信',
                          active: selected == 1,
                          onTap: () => onSelect(1),
                        ),
                        _NavItem(
                          icon: AppIcons.plus,
                          label: '发布',
                          active: false,
                          onTap: () => onSelect(2),
                        ),
                        _NavItem(
                          icon: AppIcons.bell,
                          label: '通知',
                          active: selected == 3,
                          badge: unread,
                          onTap: () => onSelect(3),
                        ),
                        _NavItem(
                          icon: AppIcons.person,
                          label: '我的',
                          active: selected == 4,
                          onTap: () => onSelect(4),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeIcon,
    this.badge = 0,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semanticLabel = badge > 0 ? '$label，$badge 条未读' : label;
    final iconColor = active ? colors.ink : colors.ink.withValues(alpha: 0.55);

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: semanticLabel,
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 600),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: active ? 1.06 : 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Icon(
                      active ? (activeIcon ?? icon) : icon,
                      size: 23,
                      color: iconColor,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: colors.danger,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          textAlign: TextAlign.center,
                          style: AppText.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
