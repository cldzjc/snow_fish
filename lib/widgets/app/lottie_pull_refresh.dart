import 'package:flutter/material.dart';

import 'immersive.dart';

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
    this.threshold = 72,
    this.dragFactor = 1,
    this.holdHeight = 72,
    this.redrawDuration = const Duration(milliseconds: 720),
    this.settleDuration = const Duration(milliseconds: 280),
    this.holdAfterRefresh = const Duration(milliseconds: 320),
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
  /// 回弹时长。
  final Duration settleDuration;

  /// 数据返回后、回弹前的停留时长，避免动画一晃而过看不清结果。
  final Duration holdAfterRefresh;

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

  /// 刷新结束后，本次手势不再允许重新触发（要等下一次按下）。
  bool _blockedThisGesture = false;

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

  Future<void> _animateGap(
    double to, {
    Duration duration = const Duration(milliseconds: 220),
  }) async {
    _gapAnim.stop();
    _gapFrom = _gap;
    _gapTo = to.clamp(0.0, _maxGap);
    _gapAnim.duration = duration;
    await _gapAnim.forward(from: 0).orCancel.catchError((Object _) {});
  }

  void _applyGap(double value) {
    final gap = value.clamp(0.0, _maxGap);
    if ((gap - _gap).abs() < 0.5) return;
    setState(() => _gap = gap);
    _gesture = (gap / widget.threshold).clamp(0.0, 1.0);
    widget.controller
      ..stop()
      ..value = _gesture * _eraseAnchor;
    // 拉到位就立即开始刷新，不需要松手。
    if (_gesture >= 1) _startRefresh();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!widget.enabled || notification.depth != 0) return false;
    // 下拉刷新过程中不让顶部/底部栏跟着收起，logo 要在原位擦除再重绘。
    if (_gap <= 1 && !_refreshing) reportImmersiveScroll(notification);
    if (_refreshing) return false;

    if (notification is ScrollStartNotification) {
      _dragging = true;
      _blockedThisGesture = false;
      _gapAnim.stop();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      _nativeOverscroll = pixels < 0 ? -pixels : 0;
      if (_nativeOverscroll > 0 && !_blockedThisGesture) {
        revealChrome();
        _applyGap(_nativeOverscroll);
      }
      return false;
    }

    if (notification is OverscrollNotification) {
      final delta = -notification.overscroll;
      if (delta > 0 &&
          notification.metrics.pixels <= 0 &&
          !_blockedThisGesture) {
        _gapAnim.stop();
        revealChrome();
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

  /// 拉到位立即触发：先跑到阈值锁定位置，再自动播放重绘并刷新。
  ///
  /// 回弹（gap → 0）一定要等真实刷新结束，所以顺序是：
  ///   重绘动画 + 数据请求（并行） → 短暂停留 → 回弹。
  Future<void> _startRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _gesture = 1;
    widget.controller.stop();
    await _animateGap(
      widget.threshold,
      duration: const Duration(milliseconds: 120),
    );
    if (!mounted) return;

    final redraw = widget.controller
        .animateTo(1, duration: widget.redrawDuration, curve: Curves.easeInOut)
        .orCancel
        .catchError((Object _) {});
    final refresh = widget.onRefresh().catchError((Object _) {});

    await Future.wait<void>(<Future<void>>[redraw, refresh]);
    if (!mounted) return;

    // 数据已到位，停一下让用户看清刷新结果，再回弹。
    await Future<void>.delayed(widget.holdAfterRefresh);
    if (!mounted) return;

    await _animateGap(0, duration: widget.settleDuration);
    if (!mounted) return;
    // 1.0 与 0 都是「完整 logo」，直接归零不会有可见跳变。
    widget.controller.value = 0;
    setState(() {
      _refreshing = false;
      _gesture = 0;
      _gap = 0;
      _nativeOverscroll = 0;
    });
    // 同一次下拉不再重复触发，必须重新按下。
    _blockedThisGesture = true;
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
