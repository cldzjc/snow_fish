import 'package:flutter/material.dart';

/// 当前是否进入「沉浸式」状态（顶部/底部栏收起）。
///
/// 只由首页信息流的滚动方向驱动：向下滚动隐藏，向上滚动或回到顶部恢复。
final ValueNotifier<bool> immersiveHidden = ValueNotifier<bool>(false);

/// 把滚动通知翻译成沉浸式状态。
void reportImmersiveScroll(ScrollNotification notification) {
  if (notification.depth != 0) return;
  if (notification is ScrollUpdateNotification) {
    final delta = notification.scrollDelta ?? 0;
    if (notification.metrics.pixels <= 6) {
      if (immersiveHidden.value) immersiveHidden.value = false;
      return;
    }
    if (delta > 1.5) {
      if (!immersiveHidden.value) immersiveHidden.value = true;
    } else if (delta < -1.5) {
      if (immersiveHidden.value) immersiveHidden.value = false;
    }
  } else if (notification is ScrollEndNotification) {
    if (notification.metrics.pixels <= 6 && immersiveHidden.value) {
      immersiveHidden.value = false;
    }
  }
}

/// 随沉浸式状态收起 / 展开的一段界面。
///
/// [alignment] 决定收起时保留哪一端：顶部栏用 bottomCenter（向上滑走），
/// 底部栏用 topCenter（向下收起）。
class ImmersiveHide extends StatelessWidget {
  const ImmersiveHide({
    super.key,
    required this.child,
    this.alignment = Alignment.bottomCenter,
    this.duration = const Duration(milliseconds: 260),
  });

  final Widget child;
  final Alignment alignment;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: immersiveHidden,
      builder: (context, hidden, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: hidden ? 1 : 0),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, value, inner) {
            if (value <= 0.001) return inner!;
            return ClipRect(
              child: Align(
                alignment: alignment,
                heightFactor: 1 - value,
                child: Opacity(opacity: 1 - value, child: inner),
              ),
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }
}
