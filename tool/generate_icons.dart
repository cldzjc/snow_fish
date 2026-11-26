// 生成 Web / PWA 用到的全部图标。
//
// 用法：dart run tool/generate_icons.dart
// 源文件：assets/brand/app_icon_source.png（黑底圆角 + 白色笔迹）
//
// 产物写到 web/ 下，随 flutter build web 一起发布：
//   icons/Icon-192.png / Icon-512.png            普通图标（保留圆角）
//   icons/Icon-maskable-192.png / -512.png       Android 自适应图标（满底黑 + 居中留白）
//   icons/apple-touch-icon.png  (180)            iOS 主屏
//   favicon.png                 (64)              浏览器标签页
//   icons/og-image.png          (1200x630)       分享预览
import 'dart:io';

import 'package:image/image.dart' as img;

const String sourcePath = 'assets/brand/app_icon_source.png';

img.Color _brandBlack(img.Image source) {
  // 取圆角方块内部的像素（顶边中点），作为满底色，避免出现一圈色差。
  final pixel = source.getPixel(source.width ~/ 2, 2);
  return img.ColorRgb8(pixel.r.round(), pixel.g.round(), pixel.b.round());
}

img.Image _onBlackBackground(
  img.Image source,
  int size, {
  double scale = 1.0,
}) {
  final canvas = img.Image(width: size, height: size);
  img.fill(canvas, color: _brandBlack(source));
  final inner = (size * scale).round();
  final scaled = img.copyResize(
    source,
    width: inner,
    height: inner,
    interpolation: img.Interpolation.average,
  );
  final offset = ((size - inner) / 2).round();
  img.compositeImage(canvas, scaled, dstX: offset, dstY: offset);
  return canvas;
}

void main() {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    stderr.writeln('找不到源文件 $sourcePath');
    exit(1);
  }
  final source = img.decodePng(file.readAsBytesSync());
  if (source == null) {
    stderr.writeln('无法解码 $sourcePath');
    exit(1);
  }
  stdout.writeln('源图 ${source.width}x${source.height}');

  void save(String path, img.Image image) {
    final target = File(path);
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(img.encodePng(image));
    stdout.writeln('  -> $path  ${image.width}x${image.height}');
  }

  for (final size in <int>[192, 512]) {
    save(
      'web/icons/Icon-$size.png',
      img.copyResize(
        source,
        width: size,
        height: size,
        interpolation: img.Interpolation.average,
      ),
    );
  }

  // maskable：满底黑，图形缩到 72%，避开系统圆形 / 方形裁切
  for (final size in <int>[192, 512]) {
    save(
      'web/icons/Icon-maskable-$size.png',
      _onBlackBackground(source, size, scale: 0.72),
    );
  }

  save('web/icons/apple-touch-icon.png', _onBlackBackground(source, 180));
  save('web/favicon.png', img.copyResize(source, width: 64, height: 64));

  // 分享预览 1200x630，品牌黑底居中
  final og = img.Image(width: 1200, height: 630);
  img.fill(og, color: _brandBlack(source));
  final glyph = img.copyResize(
    source,
    width: 440,
    height: 440,
    interpolation: img.Interpolation.average,
  );
  img.compositeImage(
    og,
    glyph,
    dstX: (1200 - 440) ~/ 2,
    dstY: (630 - 440) ~/ 2,
  );
  save('web/icons/og-image.png', og);

  stdout.writeln('完成');
}
