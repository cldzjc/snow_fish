import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

Future<File?> cropImageWithUi(
  BuildContext context,
  String imagePath, {
  double aspectRatio = 16 / 9,
  String title = '裁剪背景图',
}) async {
  final bytes = await File(imagePath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  return Navigator.push<File?>(
    context,
    MaterialPageRoute(
      builder: (_) => _CustomCropperPage(
        bytes: bytes,
        image: decoded,
        aspectRatio: aspectRatio,
        title: title,
      ),
    ),
  );
}

class _CustomCropperPage extends StatefulWidget {
  const _CustomCropperPage({
    required this.bytes,
    required this.image,
    required this.aspectRatio,
    required this.title,
  });

  final Uint8List bytes;
  final img.Image image;
  final double aspectRatio;
  final String title;

  @override
  State<_CustomCropperPage> createState() => _CustomCropperPageState();
}

class _CustomCropperPageState extends State<_CustomCropperPage> {
  final TransformationController _controller = TransformationController();
  bool _isInitialized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = constraints.biggest;
          final cropSize = _calculateCropSize(constraints);
          final cropRect = _cropRectFor(screenSize, cropSize);
          final displaySize = _calculateDisplaySize(
            cropSize,
            widget.image.width.toDouble(),
            widget.image.height.toDouble(),
          );
          final minScale = _minScaleFor(displaySize, cropRect);

          if (!_isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final dx = (screenSize.width - displaySize.width * minScale) / 2;
              final dy =
                  (screenSize.height - displaySize.height * minScale) / 2;
              _controller.value = Matrix4.identity()
                ..translate(dx, dy)
                ..scale(minScale);
              _isInitialized = true;
            });
          }

          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: minScale,
                  maxScale: 4.0,
                  boundaryMargin: EdgeInsets.zero,
                  panEnabled: true,
                  scaleEnabled: true,
                  onInteractionEnd: (_) {
                    _clampTransform(
                      screenSize,
                      displaySize,
                      cropRect,
                      minScale,
                    );
                  },
                  child: SizedBox(
                    width: displaySize.width,
                    height: displaySize.height,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    size: screenSize,
                    painter: _CropOverlayPainter(cropRect: cropRect),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: () async {
                      final cropped = await _cropToFile(context);
                      if (!context.mounted) return;
                      Navigator.pop(context, cropped);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: SafeArea(
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Size _calculateCropSize(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight * 0.7;

    double cropWidth = maxWidth - 32;
    double cropHeight = cropWidth / widget.aspectRatio;

    if (cropHeight > maxHeight) {
      cropHeight = maxHeight;
      cropWidth = cropHeight * widget.aspectRatio;
    }

    return Size(cropWidth, cropHeight);
  }

  Rect _cropRectFor(Size screenSize, Size cropSize) {
    return Rect.fromCenter(
      center: screenSize.center(Offset.zero),
      width: cropSize.width,
      height: cropSize.height,
    );
  }

  double _minScaleFor(Size displaySize, Rect cropRect) {
    final scaleX = cropRect.width / displaySize.width;
    final scaleY = cropRect.height / displaySize.height;
    return math.max(1.0, math.max(scaleX, scaleY));
  }

  void _clampTransform(
    Size screenSize,
    Size displaySize,
    Rect cropRect,
    double minScale,
  ) {
    final current = _controller.value;
    final scale = current.getMaxScaleOnAxis();
    final clampedScale = math.max(scale, minScale);

    final imageWidth = displaySize.width * clampedScale;
    final imageHeight = displaySize.height * clampedScale;

    double tx = current.storage[12];
    double ty = current.storage[13];

    final minTx = cropRect.right - imageWidth;
    final maxTx = cropRect.left;
    final minTy = cropRect.bottom - imageHeight;
    final maxTy = cropRect.top;

    if (minTx <= maxTx) {
      tx = tx.clamp(minTx, maxTx);
    } else {
      tx = (screenSize.width - imageWidth) / 2;
    }

    if (minTy <= maxTy) {
      ty = ty.clamp(minTy, maxTy);
    } else {
      ty = (screenSize.height - imageHeight) / 2;
    }

    _controller.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(clampedScale);
  }

  Size _calculateDisplaySize(Size cropSize, double imageW, double imageH) {
    double displayWidth = cropSize.width;
    double displayHeight = displayWidth * (imageH / imageW);

    if (displayHeight < cropSize.height) {
      displayHeight = cropSize.height;
      displayWidth = displayHeight * (imageW / imageH);
    }

    return Size(displayWidth, displayHeight);
  }

  Future<File?> _cropToFile(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final cropSize = _calculateCropSize(renderBox.constraints);
    final cropRect = _cropRectFor(renderBox.size, cropSize);
    final displaySize = _calculateDisplaySize(
      cropSize,
      widget.image.width.toDouble(),
      widget.image.height.toDouble(),
    );

    final inverse = Matrix4.inverted(_controller.value);
    final transformed = MatrixUtils.transformRect(inverse, cropRect);

    final scaleX = widget.image.width / displaySize.width;
    final scaleY = widget.image.height / displaySize.height;

    final left = (transformed.left * scaleX).clamp(0, widget.image.width - 1);
    final top = (transformed.top * scaleY).clamp(0, widget.image.height - 1);
    final right = (transformed.right * scaleX).clamp(1, widget.image.width);
    final bottom = (transformed.bottom * scaleY).clamp(1, widget.image.height);

    final cropX = left.round();
    final cropY = top.round();
    final cropW = math.max(1, (right - left).round());
    final cropH = math.max(1, (bottom - top).round());

    final cropped = img.copyCrop(
      widget.image,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    final outPath = p.join(
      Directory.systemTemp.path,
      'cover_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
    return outFile;
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.cropRect});

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.45);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fullRect)
      ..addRect(cropRect);
    canvas.drawPath(maskPath, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
