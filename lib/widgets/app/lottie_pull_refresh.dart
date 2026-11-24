import 'package:flutter/material.dart';

/// 手势驱动的下拉刷新（Threads 式）。
///
/// 品牌 logo 固定在顶部不动，由外部 [controller] 驱动：
///   - 下拉：controller.value 从 0 递增到 [eraseAnchor]，logo 笔迹被擦掉；
///   - 越过阈值松手：controller 自动从 [eraseAnchor] 播放到 1，logo 重新画出，
///     同时执行 [onRefresh]；
///   - 两者都结束后收起位移，回到正常顶部。
///
/// 刷新逻辑本身完全交给 [onRefresh]，这里不改业务代码。
class LottiePullRefresh extends StatefulWidget {
  const LottiePullRefresh({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.child,
    this.threshold = 78,
    this.dragFactor = 0.85,
    this.holdHeight = 78,
    this.redrawDuration = const Duration(milliseconds: 720),
    this.settleDuration = const Duration(milliseconds: 200),
    this.enabled = true,
  });

  /// 由本组件驱动的动画控制器（0..1）。
  final AnimationController controller;

  final Future<void> Function() onRefresh;

  final Widget child;

  /// 触发刷新所需的下拉距离（逻辑像素，已含阻尼）。
  final double threshold;

  /// 手指位移到下拉距离的阻尼系数。
  final double dragFactor;

  /// 刷新过程中内容保持下移的高度。
  final double holdHeight;

  /// 松手后「重新画完 logo」的时长。
  final Duration redrawDuration;

  /// 未达阈值时回弹时长。
  final Duration settleDuration;

  final bool enabled;

  @override
  State<LottiePullRefresh> createState() => _LottiePullRefreshState();
}

class _LottiePullRefreshState extends State<LottiePullRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gapAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  double _gapFrom = 0;
  double _gapTo = 0;
  double _gap = 0;

  /// 手势进度 0..1。
  double _gesture = 0;

  /// 原生滚动已经提供的负向溢出（iOS 回弹）。
  double _nativeOverscroll = 0;

  bool _dragging = false;
  bool _refreshing = false;

  /// refresh.json 中「完全擦除」的进度点，下拉阶段只走到这里。
  static const double _eraseAnchor = 0.44;

  @override
  void initState() {
    super.initState();
    _gapAnim.addListener(_onGapTick);
  }

  @override
  void dispose() {
    _gapAnim.removeListener(_onGapTick);
    _gapAnim.dispose();
    super.dispose();
  }

  double get _maxGap => widget.threshold * 1.3;

  void _onGapTick() {
    final eased = Curves.easeOutCubic.transform(_gapAnim.value);
    final next = _gapFrom + (_gapTo - _gapFrom) * eased;
    if ((next - _gap).abs() < 0.1) return;
    setState(() => _gap = next);
  }

  void _animateGap(
    double to, {
    Duration duration = const Duration(milliseconds: 220),
  }) {
    _gapAnim.stop();
    _gapFrom = _gap;
    _gapTo = to.clamp(0.0, _maxGap);
    _gapAnim.duration = duration;
    _gapAnim.forward(from: 0);
  }

  void _applyGap(double value) {
    final gap = value.clamp(0.0, _maxGap);
    if ((gap - _gap).abs() < 0.5) return;
    setState(() => _gap = gap);
    _gesture = (gap / widget.threshold).clamp(0.0, 1.0);
    widget.controller
      ..stop()
      ..value = _gesture * _eraseAnchor;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!widget.enabled || notification.depth != 0) return false;
    if (_refreshing) return false;

    if (notification is ScrollStartNotification) {
      _dragging = true;
      _gapAnim.stop();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      _nativeOverscroll = pixels < 0 ? -pixels : 0;
      if (_nativeOverscroll > 0) _applyGap(_nativeOverscroll);
      return false;
    }

    if (notification is OverscrollNotification) {
      final delta = -notification.overscroll;
      if (delta > 0 && notification.metrics.pixels <= 0) {
        _gapAnim.stop();
        _applyGap(_gap + delta * widget.dragFactor);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      _nativeOverscroll = 0;
      _release();
    }
    return false;
  }

  void _onPointerRelease(PointerEvent event) {
    if (!_dragging) return;
    _release();
  }

  void _release() {
    if (_refreshing) {
      _dragging = false;
      return;
    }
    _dragging = false;
    if (_gesture >= 1) {
      _startRefresh();
    } else {
      _settleBack();
    }
  }

  void _settleBack() {
    _gesture = 0;
    widget.controller.animateTo(
      0,
      duration: widget.settleDuration,
      curve: Curves.easeOut,
    );
    _animateGap(0, duration: widget.settleDuration);
  }

  Future<void> _startRefresh() async {
    setState(() => _refreshing = true);
    _gesture = 1;
    _animateGap(widget.holdHeight, duration: const Duration(milliseconds: 160));

    final redraw = widget.controller
        .animateTo(1, duration: widget.redrawDuration, curve: Curves.easeInOut)
        .orCancel
        .catchError((Object _) {});
    final refresh = widget.onRefresh().catchError((Object _) {});

    await Future.wait<void>(<Future<void>>[redraw, refresh]);
    if (!mounted) return;

    _animateGap(0, duration: const Duration(milliseconds: 220));
    // 1.0 与 0 都是「完整 logo」，直接归零不会有可见跳变。
    widget.controller.value = 0;
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _gesture = 0;
      _gap = 0;
      _nativeOverscroll = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // iOS 回弹时原生滚动已经移动了内容，只补差值，避免位移翻倍。
    final extra = _gap - _nativeOverscroll;
    final offset = extra > 0 ? extra : 0.0;

    return Listener(
      onPointerUp: _onPointerRelease,
      onPointerCancel: _onPointerRelease,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: ClipRect(
          child: Transform.translate(
            offset: Offset(0, offset),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
