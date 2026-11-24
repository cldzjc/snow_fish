import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../theme/app_colors.dart';

/// 开屏动画。
///
/// 素材放在 `assets/brand/splash.json`（Lottie）。文件不存在时静默跳过，
/// 不阻塞首帧，也不会留下空白遮罩。
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  static const String assetPath = 'assets/brand/splash.json';

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  static const Duration _minDuration = Duration(milliseconds: 1600);

  bool _assetReady = false;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await rootBundle.load(SplashGate.assetPath);
    } catch (_) {
      // 还没有放素材，直接进入应用。
      return;
    }
    if (!mounted) return;
    setState(() {
      _assetReady = true;
      _visible = true;
    });
    await Future<void>.delayed(_minDuration);
    if (!mounted) return;
    setState(() => _visible = false);
    // 动画播完后再释放资源。
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() => _assetReady = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_assetReady) return widget.child;
    final colors = context.colors;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: ColoredBox(
                color: colors.paper,
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = (constraints.maxWidth * 0.68).clamp(
                        0.0,
                        420.0,
                      );
                      return SizedBox(
                        width: size,
                        height: size,
                        child: Lottie.asset(
                          SplashGate.assetPath,
                          repeat: false,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
