/// OSS 图片地址处理。
///
/// 数据库里存的是原图地址（可能是几百 KB 到几 MB，甚至是浏览器无法解码的 HEIC）。
/// 展示时统一走 OSS 图片处理：按需要的尺寸生成缩略图，并强制转成 JPEG。
/// 这样头像和卡片封面不会因为原图过大或格式不支持而长时间空白。
library;

const Set<String> _ossImageExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.bmp',
  '.webp',
  '.tiff',
  '.heic',
  '.heif',
};

bool _isOssUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.contains('aliyuncs.com') || host.contains('myqcloud.com');
}

String _pathExtension(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}

/// 是否是可以交给 OSS 处理的静态图片地址。
///
/// SVG 和 GIF 不参与处理：SVG 不能栅格化，GIF 转 JPEG 会丢掉动画。
bool isOssImageUrl(String? url) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return false;
  if (!_isOssUrl(raw)) return false;
  return _ossImageExtensions.contains(_pathExtension(raw));
}

/// 生成缩略图地址；非 OSS 图片或非图片地址原样返回。
///
/// [width] / [height] 都给时按 [crop] 决定是否填充裁切，只给一个时等比缩放。
String mediaThumb(String? url, {int? width, int? height, bool crop = true}) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return raw;
  if (raw.contains('x-oss-process=')) return raw;
  if (!isOssImageUrl(raw)) return raw;

  final ops = <String>[];
  final w = width;
  final h = height;
  if (w != null && h != null) {
    ops.add(crop ? 'resize,m_fill,w_$w,h_$h' : 'resize,w_$w,h_$h');
  } else if (w != null) {
    ops.add('resize,w_$w');
  } else if (h != null) {
    ops.add('resize,h_$h');
  }
  // HEIC / TIFF 等浏览器不支持的格式，靠这一步转成 JPEG 后才能显示。
  ops.add('format,jpg');
  ops.add('quality,q_82');

  final separator = raw.contains('?') ? '&' : '?';
  return '$raw${separator}x-oss-process=image/${ops.join('/')}';
}

/// 头像专用尺寸：按显示大小取 3 倍像素，兼顾清晰度与体积。
String avatarThumb(String? url, double size) {
  final pixels = (size * 3).round().clamp(64, 400);
  return mediaThumb(url, width: pixels, height: pixels);
}
