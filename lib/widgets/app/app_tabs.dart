import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 等分下划线 Tab。
///
/// 文案小一号、下划线只画在文字宽度上，视觉更轻，给内容让出空间。
class AppTabs extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.height = 42,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Text(
                        tabs[i],
                        style: AppText.label.copyWith(
                          fontSize: 14,
                          fontWeight: i == index
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: i == index ? colors.ink : colors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        height: 2.5,
                        width: i == index ? 20 : 0,
                        decoration: BoxDecoration(
                          color: colors.ink,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 分段式筛选（用于约约约的地区与类型）。
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppOptionLike<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final option in options)
          _Segment(
            label: option.label,
            selected: option.value == value,
            onTap: () => onChanged(option.value),
            colors: colors,
          ),
      ],
    );
  }
}

class AppOptionLike<T> {
  const AppOptionLike(this.value, this.label);

  final T value;
  final String label;
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? colors.ink : colors.line),
            ),
            child: Text(
              label,
              style: AppText.bodySmall.copyWith(
                color: selected ? colors.paper : colors.muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
