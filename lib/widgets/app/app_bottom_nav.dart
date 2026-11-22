import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_icons.dart';

/// 底部导航：5 个入口，中间「发布」是动作。
///
/// [selected] 用导航槽位（0 首页 / 1 私信 / 3 通知 / 4 我的），
/// 发布不占选中态，传 -1 表示当前没有选中项。
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.md + MediaQuery.viewPaddingOf(context).bottom * 0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.line),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 6,
        ),
        child: Row(
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
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: semanticLabel,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? colors.soft : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      active ? (activeIcon ?? icon) : icon,
                      size: 22,
                      color: active ? colors.ink : colors.muted,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: 2,
                      top: -2,
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
              const SizedBox(height: 2),
              Text(
                label,
                style: AppText.caption.copyWith(
                  color: active ? colors.ink : colors.muted,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
