import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

// 媒体服务类，统一管理媒体文件的数据操作
class MediaService {
  static final SupabaseClient _client = SupabaseClientManager.instance;

  // 创建媒体记录到 media 表
  Future<Map<String, dynamic>> createMedia({
    required String userId,
    required String url,
    required String mediaType,
    required String ownerType,
    required String ownerId,
    required int sortOrder,
  }) async {
    try {
      final newMedia = {
        'user_id': userId,
        'url': url,
        'media_type': mediaType,
        'owner_type': ownerType,
        'owner_id': ownerId,
        'sort_order': sortOrder,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _client.from('media').insert(newMedia).select();

      return response.first;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 统一的商品图片上传逻辑
  Future<void> uploadImagesForOwner({
    required String userId,
    required String ownerType,
    required String ownerId,
    required List<PlatformFile> files,
  }) async {
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';

      // 获取上传信息（只传递 filename / contentType / field / owner_id）
      final info = await _getUploadInfo(
        p.basename(file.name),
        mimeType,
        'product_image',
        ownerId,
      );

      final uploadUrl = info['uploadUrl'] ?? info['upload_url'];
      final publicUrl = info['publicUrl'] ?? info['public_url'];

      // 压缩图片
      Uint8List bytes;
      if (_isImageFile(file) && file.path != null) {
        bytes = await compute(_compressImageIsolate, {
          'path': file.path!,
          'quality': 80,
          'maxWidth': 1080,
        });
      } else {
        bytes = await _readFileBytes(file);
      }

      // 上传图片
      await _uploadFileBytes(bytes, uploadUrl, mimeType);

      // 保存到media表
      await createMedia(
        userId: userId,
        url: publicUrl,
        mediaType: 'image',
        ownerType: ownerType,
        ownerId: ownerId,
        sortOrder: i,
      );
    }
  }

  // 获取指定所有者的媒体文件列表
  Future<List<Map<String, dynamic>>> getMediaByOwner({
    required String ownerType,
    required String ownerId,
  }) async {
    try {
      final response = await _client
          .from('media')
          .select('*')
          .eq('owner_type', ownerType)
          .eq('owner_id', ownerId)
          .order('sort_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 删除媒体记录
  Future<void> deleteMedia(String mediaId) async {
    try {
      await _client.from('media').delete().eq('id', mediaId);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 批量删除指定所有者的所有媒体记录
  Future<void> deleteMediaByOwner({
    required String ownerType,
    required String ownerId,
  }) async {
    try {
      await _client
          .from('media')
          .delete()
          .eq('owner_type', ownerType)
          .eq('owner_id', ownerId);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 更新媒体记录
  Future<void> updateMedia(String mediaId, Map<String, dynamic> updates) async {
    try {
      await _client.from('media').update(updates).eq('id', mediaId);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 获取上传信息的私有方法
  Future<Map<String, dynamic>> _getUploadInfo(
    String filename,
    String contentType,
    String field,
    String ownerId,
  ) async {
    // Edge Function 只接收 filename / contentType / field / owner_id
    final body = jsonEncode({
      'filename': filename,
      'contentType': contentType,
      'field': field,
      'owner_id': ownerId,
    });

    try {
      final resp = await _client.functions.invoke(
        'get-oss-upload-url',
        body: body,
      );
      // Expect function return shape: {"uploadUrl": "...", "publicUrl": "..."}
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) throw Exception('Edge function returned no data');
      return data;
    } on FunctionException catch (fe) {
      throw Exception(
        "Edge Function 调用失败 (${fe.status}): ${fe.toString()}. 请确认函数名 'get-oss-upload-url' 已部署并可用。",
      );
    } catch (e) {
      throw Exception('调用 Edge Function 失败: $e');
    }
  }

  // 检查是否为图片文件的私有方法
  bool _isImageFile(PlatformFile file) {
    final mime = lookupMimeType(file.name) ?? '';
    return mime.startsWith('image/');
  }

  // 读取文件字节的私有方法
  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return await File(file.path!).readAsBytes();
    throw Exception('File bytes unavailable for ${file.name}');
  }

  // 上传文件字节的私有方法
  Future<void> _uploadFileBytes(
    Uint8List bytes,
    String uploadUrl,
    String contentType,
  ) async {
    final dio = Dio();
    final headers = {
      'content-type': contentType,
      'content-length': bytes.length.toString(),
    };

    try {
      // Upload as a stream with content-length
      final stream = Stream.fromIterable([bytes]);
      await dio.put(
        uploadUrl,
        data: stream,
        options: Options(headers: headers),
      );
    } catch (e) {
      throw Exception('Upload failed: $e');
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
