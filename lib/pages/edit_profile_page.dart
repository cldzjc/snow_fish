import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _introController = TextEditingController();

  String? _avatarUrl;
  String? _coverUrl;
  String? _videoUrl;

  PlatformFile? _pickedAvatar;
  PlatformFile? _pickedCover;

  bool _isSaving = false;

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
      final data = res as Map<String, dynamic>;
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
        _videoUrl =
            (data['video_url'] as String?) ??
            (data['profile_video_url'] as String?);
      });
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedAvatar = result.files.first);
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedCover = result.files.first);
    }
  }

  /// Calls edge function to get uploadUrl and publicUrl
  Future<Map<String, dynamic>> _getUploadInfo(
    String filename,
    String contentType,
  ) async {
    // Edge Function expects `filename` and `contentType` as keys
    final body = jsonEncode({
      'filename': filename,
      'contentType': contentType,
      'owner_type': 'user_profiles',
      'owner_id': Supabase.instance.client.auth.currentUser!.id,
    });

    try {
      final resp = await Supabase.instance.client.functions.invoke(
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
    final dio = Dio();
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

      // Upload as a stream with content-length so servers/clients can handle it efficiently
      final stream = Stream.fromIterable([bytes]);
      await dio.put(
        uploadUrl,
        data: stream,
        options: Options(headers: headers),
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
        );
        final uploadUrl = info['uploadUrl'] ?? info['upload_url'];
        final publicUrl = info['publicUrl'] ?? info['public_url'];
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
      }

      // cover
      if (_pickedCover != null) {
        final mimeType =
            lookupMimeType(_pickedCover!.name) ?? 'application/octet-stream';
        final info = await _getUploadInfo(
          p.basename(_pickedCover!.name),
          mimeType,
        );
        final uploadUrl = info['uploadUrl'] ?? info['upload_url'];
        final publicUrl = info['publicUrl'] ?? info['public_url'];
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

      final res = await Supabase.instance.client
          .from('user_profiles')
          .update(updates)
          .eq('id', user.id)
          .select();
      if (res == null) throw Exception('Update failed');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
        Navigator.of(context).pop(true); // signal updated
      }
    } catch (e) {
      // Log full error for debugging
      // Provide a user-friendly message for common cases (e.g., function not found)
      debugPrint('EditProfilePage._save error: $e');
      final errStr = e.toString();
      String userMessage = '保存失败: $errStr';
      if (errStr.contains('Edge Function 调用失败') ||
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
