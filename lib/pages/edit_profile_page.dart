import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cropper.dart';

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

/// EditProfilePage
/// - Fetches current user's row in `user_profiles`
/// - Allows editing username, intro
/// - Pick avatar / cover / video files using FilePicker
/// - For each picked file: call Supabase Edge Function `get-oss-upload-url` to get `uploadUrl` + `publicUrl`, then HTTP PUT file bytes to `uploadUrl`
/// - On success, updates `user_profiles` with returned `publicUrl`s
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _introController = TextEditingController();

  String? _avatarUrl;
  String? _coverUrl;

  PlatformFile? _pickedAvatar;
  PlatformFile? _pickedCover;

  bool _isSaving = false;
  bool _isCroppingCover = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (res != null) {
      final data = res as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          // Support both old/new column names: username <-> nickname, intro <-> bio,
          // cover_url <-> background_url, video_url <-> profile_video_url
          _usernameController.text =
              (data['username'] as String?) ??
              (data['nickname'] as String?) ??
              '';
          _introController.text =
              (data['intro'] as String?) ?? (data['bio'] as String?) ?? '';
          _avatarUrl =
              (data['avatar_url'] as String?) ?? (data['avatar'] as String?);
          _coverUrl =
              (data['cover_url'] as String?) ??
              (data['background_url'] as String?);
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedAvatar = result.files.first);
    }
  }

  Future<void> _pickCover() async {
    if (_isCroppingCover) return;
    _isCroppingCover = true;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        // 裁剪背景图为 16:9 比例
        final croppedFile = await cropImageWithUi(
          context,
          pickedFile.path!,
          aspectRatio: 16 / 9,
          title: '裁剪背景图',
        );

        if (croppedFile != null) {
          // 将裁剪后的文件转换为 PlatformFile
          final croppedBytes = await croppedFile.readAsBytes();
          final croppedPlatformFile = PlatformFile(
            name: pickedFile.name,
            size: croppedBytes.length,
            bytes: croppedBytes,
            path: croppedFile.path,
          );
          setState(() => _pickedCover = croppedPlatformFile);
        }
      }
    } finally {
      _isCroppingCover = false;
    }
  }

  /// Calls edge function to get uploadUrl and publicUrl
  Future<Map<String, dynamic>> _getUploadInfo(
    String filename,
    String contentType,
    String ownerType,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('用户会话已过期，请重新登录');
    }

    debugPrint('📤 发送请求到 get-oss-upload-url 函数');
    debugPrint('   文件名: $filename');
    debugPrint('   ContentType: $contentType');
    debugPrint('   UserId: ${user.id}');

    // Edge Function expects `filename`, `contentType`, `owner_type`, `owner_id`
    final body = {
      'filename': filename,
      'contentType': contentType,
      'owner_type': ownerType,
      'owner_id': user.id,
    };

    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'get-oss-upload-url',
        body: body,
      );

      // Expect function return shape: {"uploadUrl": "...", "publicUrl": "...", "objectKey": "..."}
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) throw Exception('Edge function 返回空数据');

      debugPrint('✅ 成功获取上传 URL');
      debugPrint('   ObjectKey: ${data['objectKey']}');
      return data;
    } on FunctionException catch (fe) {
      debugPrint('❌ FunctionException 状态码: ${fe.status}');
      debugPrint('❌ FunctionException 详情: ${fe.toString()}');

      throw Exception(
        "Edge Function 调用失败 (${fe.status}): ${fe.toString()}. "
        "请确认函数名 'get-oss-upload-url' 已部署并可用。",
      );
    } catch (e) {
      debugPrint('❌ 未知错误: $e');
      throw Exception('调用 Edge Function 失败: $e');
    }
  }

  bool _isImageFile(PlatformFile file) {
    final mime = lookupMimeType(file.name) ?? '';
    return mime.startsWith('image/');
  }

  // Upload using Dio and show progress updates via SnackBar
  Future<void> _uploadFileBytes(
    Uint8List bytes,
    String uploadUrl,
    String contentType,
    String label,
  ) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final headers = {
      'content-type': contentType,
      'content-length': bytes.length.toString(),
    };

    try {
      // Simple indeterminate uploading message (no percent)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 上传中...'),
          duration: const Duration(hours: 1),
        ),
      );

      await dio.put(
        uploadUrl,
        data: bytes,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final percent = (sent / total * 100).toStringAsFixed(0);
            debugPrint('$label 上传进度: $percent%');
          }
        },
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 上传完成'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      throw Exception('Upload failed: $e');
    }
  }

  // Read bytes from PlatformFile; prefer in-memory bytes, fallback to reading from path
  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return await File(file.path!).readAsBytes();
    throw Exception('File bytes unavailable for ${file.name}');
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Use the existing table columns in your schema
      final updates = <String, dynamic>{
        'nickname': _usernameController.text.trim(),
        'bio': _introController.text.trim(),
      };

      // avatar
      if (_pickedAvatar != null) {
        final mimeType =
            lookupMimeType(_pickedAvatar!.name) ?? 'application/octet-stream';
        final info = await _getUploadInfo(
          p.basename(_pickedAvatar!.name),
          mimeType,
          'avatar',
        );
        final uploadUrl = info['uploadUrl'] ?? info['upload_url'];
        final publicUrl = info['publicUrl'] ?? info['public_url'];
        if (uploadUrl == null || uploadUrl is! String || uploadUrl.isEmpty) {
          throw Exception('获取上传地址失败（avatar uploadUrl 为空）');
        }
        if (publicUrl == null || publicUrl is! String || publicUrl.isEmpty) {
          throw Exception('获取公开地址失败（avatar publicUrl 为空）');
        }

        debugPrint('🖼️ Avatar upload info:');
        debugPrint('   uploadUrl: $uploadUrl');
        debugPrint('   publicUrl: $publicUrl');
        debugPrint('   objectKey: ${info['objectKey']}');

        Uint8List bytes;
        if (_isImageFile(_pickedAvatar!) && _pickedAvatar!.path != null) {
          // compress avatar to small width (e.g., 400px) in background isolate
          bytes = await compute(_compressImageIsolate, {
            'path': _pickedAvatar!.path!,
            'quality': 80,
            'maxWidth': 400,
          });
        } else {
          bytes = await _readFileBytes(_pickedAvatar!);
        }
        await _uploadFileBytes(bytes, uploadUrl, mimeType, '头像');
        updates['avatar_url'] = publicUrl;
        debugPrint('✅ Avatar 已上传，将保存 URL: $publicUrl');
      }

      // cover
      if (_pickedCover != null) {
        final mimeType =
            lookupMimeType(_pickedCover!.name) ?? 'application/octet-stream';
        final info = await _getUploadInfo(
          p.basename(_pickedCover!.name),
          mimeType,
          'cover',
        );
        final uploadUrl = info['uploadUrl'] ?? info['upload_url'];
        final publicUrl = info['publicUrl'] ?? info['public_url'];
        if (uploadUrl == null || uploadUrl is! String || uploadUrl.isEmpty) {
          throw Exception('获取上传地址失败（cover uploadUrl 为空）');
        }
        if (publicUrl == null || publicUrl is! String || publicUrl.isEmpty) {
          throw Exception('获取公开地址失败（cover publicUrl 为空）');
        }
        Uint8List bytes;
        if (_isImageFile(_pickedCover!) && _pickedCover!.path != null) {
          // compress cover to larger width (e.g., 1080px) in background isolate
          bytes = await compute(_compressImageIsolate, {
            'path': _pickedCover!.path!,
            'quality': 80,
            'maxWidth': 1080,
          });
        } else {
          bytes = await _readFileBytes(_pickedCover!);
        }
        await _uploadFileBytes(bytes, uploadUrl, mimeType, '背景');
        updates['background_url'] = publicUrl;
      }

      // 确保表中存在该用户的行
      final existingRow = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingRow == null) {
        // 如果行不存在，先插入一行
        debugPrint('ℹ️ user_profiles 中不存在该用户，创建新行...');
        await Supabase.instance.client.from('user_profiles').insert({
          'id': user.id,
          ...updates,
        });
        debugPrint('✅ 已创建 user_profiles 行');
      } else {
        // 如果行存在，更新数据
        debugPrint('ℹ️ user_profiles 中已存在该用户，更新数据...');
        await Supabase.instance.client
            .from('user_profiles')
            .update(updates)
            .eq('id', user.id);
      }

      debugPrint('💾 已保存到 user_profiles:');
      debugPrint('   user_id: ${user.id}');
      debugPrint('   updates: $updates');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
        Navigator.of(context).pop(true); // signal updated
      }
    } catch (e) {
      // Log full error for debugging
      debugPrint('EditProfilePage._save error: $e');
      final errStr = e.toString();
      String userMessage = '保存失败: $errStr';

      // 提供更友好的错误信息
      if (errStr.contains('认证失败') ||
          errStr.contains('JWT') ||
          errStr.contains('401')) {
        userMessage = '登录已过期，请退出后重新登录';
      } else if (errStr.contains('会话已过期')) {
        userMessage = '登录会话已过期，请重新登录';
      } else if (errStr.contains('Edge Function 调用失败') ||
          errStr.contains('Requested function was not found') ||
          errStr.contains('status: 404') ||
          errStr.contains('FunctionException')) {
        userMessage =
            "未找到 Edge Function 'get-oss-upload-url'（404）。请确认该函数已在 Supabase 控制台部署，或确认 `supabaseUrl` 指向正确的项目。";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑主页')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('用户名', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '用户名',
              ),
            ),
            const SizedBox(height: 16),

            const Text('个性签名', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _introController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '一句话介绍',
              ),
            ),
            const SizedBox(height: 16),

            // Avatar picker
            const Text('头像', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _pickedAvatar != null
                    ? (_pickedAvatar!.bytes != null
                          ? Image.memory(
                              _pickedAvatar!.bytes!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_pickedAvatar!.path!),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ))
                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _avatarUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.person),
                              ),
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: const Icon(Icons.person),
                            )),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _pickAvatar,
                  child: const Text('选择头像'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cover picker
            const Text('背景图', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _pickedCover != null
                    ? (_pickedCover!.bytes != null
                          ? Image.memory(
                              _pickedCover!.bytes!,
                              width: 120,
                              height: 70,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_pickedCover!.path!),
                              width: 120,
                              height: 70,
                              fit: BoxFit.cover,
                            ))
                    : (_coverUrl != null && _coverUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _coverUrl!,
                              width: 120,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 120,
                                height: 70,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 120,
                                height: 70,
                                color: Colors.grey[200],
                              ),
                            )
                          : Container(
                              width: 120,
                              height: 70,
                              color: Colors.grey[200],
                            )),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _pickCover,
                  child: const Text('选择背景'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
