import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'supabase_client.dart';
import 'models/media_model.dart';

/// 不支持的视频格式异常
class UnsupportedVideoException implements Exception {
  final String message;
  UnsupportedVideoException(this.message);

  @override
  String toString() => message;
}

/// 媒体服务类
/// 统一处理：选择 -> 压缩 -> 上传 -> 入库
class MediaService {
  static final SupabaseClient _client = SupabaseClientManager.instance;

  /// 选择和上传媒体文件
  /// 支持图片和视频
  /// 自动压缩图片（maxWidth: 1080px, quality: 80）
  /// 返回上传成功的 MediaModel 对象
  Future<MediaModel> uploadMedia({
    required String userId,
    required String entityId,
    required FileType fileType,
    int maxWidth = 1080,
    int quality = 80,
  }) async {
    // 1. 选择文件
    final result = await FilePicker.platform.pickFiles(type: fileType);
    if (result == null || result.files.isEmpty) {
      throw Exception('用户未选择文件');
    }

    final file = result.files.first;
    return _uploadFileToEntity(
      file: file,
      userId: userId,
      entityId: entityId,
      maxWidth: maxWidth,
      quality: quality,
    );
  }

  /// 上传已选择的媒体文件（使用 PlatformFile）
  /// 用于在发布流程中上传用户已选择的文件
  Future<MediaModel> uploadMediaFile({
    required PlatformFile file,
    required String userId,
    required String entityId,
    int maxWidth = 1080,
    int quality = 80,
  }) async {
    // 检查是否为第三方应用视频
    final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
    final isVideo = mimeType.startsWith('video');
    final fileName = file.name.toLowerCase();

    if (isVideo &&
        (fileName.contains('wx_camera') || fileName.contains('douyin'))) {
      // 返回警告信息，让调用方处理
      print('⚠️ 检测到 WeChat/抖音 视频：${file.name}');
      throw UnsupportedVideoException('暂不支持微信/抖音拍摄的视频上传哦，麻烦上传系统相机视频或转码为H.264');
    }

    return _uploadFileToEntity(
      file: file,
      userId: userId,
      entityId: entityId,
      maxWidth: maxWidth,
      quality: quality,
    );
  }

  /// 实际的文件上传逻辑
  Future<MediaModel> _uploadFileToEntity({
    required PlatformFile file,
    required String userId,
    required String entityId,
    required int maxWidth,
    required int quality,
  }) async {
    final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
    final mediaType = mimeType.startsWith('image') ? 'image' : 'video';

    print('📁 文件上传: ${file.name}');
    print('   MIME type: $mimeType');
    print('   Media type: $mediaType');
    print('   文件大小: ${file.size} bytes');

    // 视频格式检查
    if (mediaType == 'video') {
      print('   ⚠️ 警告：上传的是视频文件');
      print('      建议使用系统相机录制的视频，避免使用第三方应用录制的视频');
      print('      微信、抖音等应用的视频可能使用特殊编码格式导致兼容性问题');

      if (file.name.toLowerCase().contains('wx_camera') ||
          file.name.toLowerCase().contains('douyin')) {
        print('      ⚠️ 检测到第三方应用视频，可能出现播放问题');
      }
    }

    // 2. 压缩（如果是图片）
    Uint8List bytes;
    if (mediaType == 'image' && file.path != null) {
      bytes = await compute(_compressImageIsolate, {
        'path': file.path!,
        'quality': quality,
        'maxWidth': maxWidth,
      });
    } else {
      bytes = await _readFileBytes(file);
    }

    // 3. 调用 Edge Function 获取上传 URL
    final uploadInfo = await _getUploadInfo(
      filename: p.basename(file.name),
      contentType: mimeType,
      entityType: 'entity', // 使用通用 entity_type
      ownerId: userId,
    );

    final uploadUrl = uploadInfo['uploadUrl'];
    final publicUrl = uploadInfo['publicUrl'];

    if (uploadUrl == null || publicUrl == null) {
      throw Exception('上传信息不完整');
    }

    // 4. 上传到 OSS
    print('   ☁️ 上传到 OSS...');
    await _uploadFileBytes(bytes, uploadUrl, mimeType);
    print('   ✅ OSS 上传成功');

    // 5. 向 media 表插入记录，关联到 entity_id
    final mediaId = _generateUUID();
    final newMedia = {
      'id': mediaId,
      'user_id': userId,
      'entity_id': entityId,
      'url': publicUrl,
      'media_type': mediaType,
      'sort_order': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    print('   📝 插入 media 表记录:');
    print('      publicUrl: $publicUrl');
    print('      mediaType: $mediaType');

    final response = await _client
        .from('media')
        .insert(newMedia)
        .select()
        .single();

    print('   ✅ media 表插入成功');
    return MediaModel.fromJson(response);
  }

  /// 创建媒体记录到 media 表（直接使用 URL）
  Future<MediaModel> createMediaFromUrl({
    required String userId,
    required String entityId,
    required String url,
    required String mediaType,
    int sortOrder = 0,
    String? thumbnailUrl,
  }) async {
    try {
      final mediaId = _generateUUID();
      final newMedia = {
        'id': mediaId,
        'user_id': userId,
        'entity_id': entityId,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'media_type': mediaType,
        'sort_order': sortOrder,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _client
          .from('media')
          .insert(newMedia)
          .select()
          .single();

      return MediaModel.fromJson(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 获取实体的所有媒体
  Future<List<MediaModel>> getMediaByEntity(String entityId) async {
    try {
      final response = await _client
          .from('media')
          .select()
          .eq('entity_id', entityId)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((m) => MediaModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 删除媒体记录
  Future<void> deleteMedia(String mediaId) async {
    try {
      await _client.from('media').delete().eq('id', mediaId);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 删除实体的所有媒体
  Future<void> deleteMediaByEntity(String entityId) async {
    try {
      await _client.from('media').delete().eq('entity_id', entityId);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 更新媒体记录
  Future<void> updateMedia(String mediaId, Map<String, dynamic> updates) async {
    try {
      await _client.from('media').update(updates).eq('id', mediaId);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// 调用 Edge Function 获取上传 URL
  /// 返回 {uploadUrl, publicUrl, objectKey}
  Future<Map<String, dynamic>> _getUploadInfo({
    required String filename,
    required String contentType,
    required String entityType,
    required String ownerId,
  }) async {
    final body = jsonEncode({
      'filename': filename,
      'contentType': contentType,
      'entity_type': entityType,
      'owner_id': ownerId,
    });

    try {
      final resp = await _client.functions.invoke(
        'get-oss-upload-url',
        body: body,
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) throw Exception('Edge function returned no data');
      return data;
    } on FunctionException catch (fe) {
      throw Exception("Edge Function 调用失败 (${fe.status}): ${fe.toString()}");
    } catch (e) {
      throw Exception('调用 Edge Function 失败: $e');
    }
  }

  /// 读取文件字节
  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return await File(file.path!).readAsBytes();
    throw Exception('File bytes unavailable for ${file.name}');
  }

  /// 上传文件字节到 OSS（流式 + 重试机制）
  /// 最多重试 10 次，采用指数退避策略
  Future<void> _uploadFileBytes(
    Uint8List bytes,
    String uploadUrl,
    String contentType,
  ) async {
    print('🔄 开始上传文件字节流:');
    print('   总大小: ${bytes.length} bytes');
    print('   URL: $uploadUrl');

    int retryCount = 0;
    const int maxRetries = 3;

    while (retryCount < maxRetries) {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.sendTimeout = const Duration(seconds: 300);

      try {
        print('   🔄 上传尝试 ${retryCount + 1}/$maxRetries');

        final response = await dio.put(
          uploadUrl,
          data: bytes, // 直接传递字节，而不是流
          options: Options(
            headers: {
              'content-type': contentType,
              'content-length': bytes.length.toString(),
            },
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        print('   响应状态码: ${response.statusCode}');

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204) {
          print('   ✅ 上传成功');
          dio.close();
          return; // 上传成功
        } else {
          throw Exception('上传返回非成功状态码: ${response.statusCode}');
        }
      } on DioException catch (e) {
        retryCount++;
        print('   ❌ DioException (${retryCount}/$maxRetries): ${e.message}');
        dio.close();

        if (retryCount >= maxRetries) {
          throw Exception('网络环境持续异常，已重试 $maxRetries 次仍失败: ${e.message}');
        }

        // 指数退避
        final delaySeconds = (retryCount * 2) + 5;
        print('   ⏳ 等待 ${delaySeconds}s 后重试...');
        await Future.delayed(Duration(seconds: delaySeconds));
      } catch (e) {
        retryCount++;
        print('   ❌ 错误 (${retryCount}/$maxRetries): $e');
        dio.close();

        if (retryCount >= maxRetries) {
          throw Exception('上传失败: $e');
        }

        final delaySeconds = (retryCount * 2) + 5;
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// 生成 UUID
  String _generateUUID() {
    const chars = 'abcdef0123456789';
    final random = Random();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (match) {
        final isX = match.group(0) == 'x';
        final value = isX
            ? random.nextInt(16)
            : (random.nextInt(16) & 0x3) | 0x8;
        return chars[value];
      },
    );
  }

  /// 统一的错误处理
  void _handleError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
      throw Exception('network: $e');
    }
    if (msg.contains('permission') ||
        msg.contains('403') ||
        msg.contains('forbidden') ||
        msg.contains('Unauthorized')) {
      throw Exception('permission: $e');
    }
  }
}

// Top-level function for compute to compress images in a background isolate
Uint8List _compressImageIsolate(Map<String, dynamic> args) {
  final String path = args['path'] as String;
  final int quality = args['quality'] as int;
  final int maxWidth = args['maxWidth'] as int;

  final bytes = File(path).readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;
  final resized = img.copyResize(image, width: maxWidth);
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}
