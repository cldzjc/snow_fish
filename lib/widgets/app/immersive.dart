import 'package:flutter/material.dart';

/// 沉浸式进度：0 = 全部可见，1 = 顶部/底部栏完全收起。
///
/// 由首页信息流的滚动方向驱动，完全跟随手指幅度连续变化。
final ValueNotifier<double> immersiveProgress = ValueNotifier<double>(0);

/// 向下滚动多远完全收起（像素）。
const double _hideDistance = 130;

/// 向上滚动多远完全展开（像素）。
const double _showDistance = 80;

void _advance(double delta) {
  final next = (immersiveProgress.value + delta).clamp(0.0, 1.0);
  if ((next - immersiveProgress.value).abs() < 0.001) return;
  immersiveProgress.value = next;
}

/// 把滚动通知翻译成沉浸式进度。
void reportImmersiveScroll(ScrollNotification notification) {
  if (notification.depth != 0) return;
  if (notification is ScrollUpdateNotification) {
    final pixels = notification.metrics.pixels;
    if (pixels <= 4) {
      if (immersiveProgress.value != 0) immersiveProgress.value = 0;
      return;
    }
    final delta = notification.scrollDelta ?? 0;
    if (delta > 0) {
      _advance(delta / _hideDistance);
    } else if (delta < 0) {
      _advance(delta / _showDistance);
    }
  } else if (notification is ScrollEndNotification) {
    if (notification.metrics.pixels <= 4 && immersiveProgress.value != 0) {
      immersiveProgress.value = 0;
    }
  }
}

/// 立即恢复顶部与底部栏。
void revealChrome() {
  if (immersiveProgress.value != 0) immersiveProgress.value = 0;
}

/// 随沉浸式进度平移并淡出的一段界面。
///
/// [hideOffset] 是收起后额外位移：顶部栏传负的 dy（向上消失），
/// 底部栏传正的 dy（向下收起）。
class ImmersiveHide extends StatelessWidget {
  const ImmersiveHide({
    super.key,
    required this.child,
    required this.hideOffset,
  });

  final Widget child;
  final Offset hideOffset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: immersiveProgress,
      builder: (context, progress, child) {
        final visible = (1 - progress).clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: visible < 0.5,
          child: Opacity(
            opacity: visible,
            child: Transform.translate(
              offset: hideOffset * progress,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
