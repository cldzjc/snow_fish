import 'package:flutter_test/flutter_test.dart';
import 'package:snow_fish/utils/geo_format.dart';
import 'package:snow_fish/utils/media_url.dart';

void main() {
  group('mediaThumb', () {
    const ossBase =
        'https://snow-fish-media.oss-cn-hongkong.aliyuncs.com/snowfish/u1/files/a.jpg';

    test('OSS 图片会附带缩略图与 JPEG 转换参数', () {
      final url = mediaThumb(ossBase, width: 200, height: 200);
      expect(url, contains('x-oss-process=image/resize,m_fill,w_200,h_200'));
      expect(url, contains('format,jpg'));
    });

    test('HEIC 头像同样走 OSS 处理，否则浏览器无法显示', () {
      final url = avatarThumb(
        'https://snow-fish-media.oss-cn-hongkong.aliyuncs.com/a/avatar/1.HEIC',
        40,
      );
      expect(url, contains('x-oss-process='));
      expect(url, contains('format,jpg'));
    });

    test('非 OSS 地址、视频、SVG 保持原样', () {
      expect(
        mediaThumb('https://example.com/a.jpg', width: 100),
        endsWith('.jpg'),
      );
      expect(
        mediaThumb(
          'https://snow-fish-media.oss-cn-hongkong.aliyuncs.com/a/clip.mp4',
          width: 100,
        ),
        endsWith('.mp4'),
      );
      expect(
        mediaThumb(
          'https://snow-fish-media.oss-cn-hongkong.aliyuncs.com/a/icon.svg',
          width: 100,
        ),
        endsWith('.svg'),
      );
    });

    test('已有处理参数的不重复追加', () {
      const processed = '$ossBase?x-oss-process=image/format,jpg';
      expect(mediaThumb(processed, width: 200), processed);
    });
  });

  group('shortRegionLabel', () {
    test('只保留区县与去掉后缀的雪场名', () {
      expect(shortRegionLabel(region: '河北·张家口·崇礼区', resort: '富龙滑雪场'), '崇礼区·富龙');
    });

    test('没有雪场时只显示区县', () {
      expect(shortRegionLabel(region: '北京·北京市·延庆区', resort: '暂无固定雪场'), '延庆区');
    });

    test('地区为空时返回空串，不占位', () {
      expect(shortRegionLabel(region: '', resort: ''), '');
    });
  });
}
