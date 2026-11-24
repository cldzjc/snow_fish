import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// 顶栏品牌标志（由 Lottie 驱动的可擦除 logo）。
///
/// 素材是 500×500 画布，图形只占中间一条，直接渲染会缩得很小。
/// 这里按预先算出的图形包围盒裁剪，让 logo 贴合目标高度。
class BrandMarkLottie extends StatelessWidget {
  const BrandMarkLottie({
    super.key,
    required this.controller,
    this.height = 30,
    this.assetPath = 'assets/brand/refresh.json',
  });

  final AnimationController controller;

  /// logo 图形本身的高度（不含画布留白）。
  final double height;

  final String assetPath;

  /// 图形包围盒（相对 500×500 画布，已含笔迹宽度余量）。
  static const Rect artworkBox = Rect.fromLTRB(0.112, 0.335, 0.889, 0.665);

  /// 画布宽高比（refresh.json 为 500×500）。
  static const double canvasAspect = 1;

  @override
  Widget build(BuildContext context) {
    final canvasHeight = height / artworkBox.height;
    final canvasWidth = canvasHeight * canvasAspect;
    final artWidth = canvasWidth * artworkBox.width;

    return ClipRect(
      child: SizedBox(
        width: artWidth,
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: canvasWidth,
          maxWidth: canvasWidth,
          minHeight: canvasHeight,
          maxHeight: canvasHeight,
          child: Transform.translate(
            offset: Offset(
              -artworkBox.left * canvasWidth,
              -artworkBox.top * canvasHeight,
            ),
            child: SizedBox(
              width: canvasWidth,
              height: canvasHeight,
              child: Lottie.asset(
                assetPath,
                controller: controller,
                animate: false,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
