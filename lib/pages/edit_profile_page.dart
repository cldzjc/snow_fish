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
import '../services/profile_sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/geo_picker_sheet.dart';

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
  String? _residentRegion;
  String _residentResort = '暂无固定雪场';

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
          _residentRegion = (data['resident_region'] as String?)?.trim();
          _residentResort =
              (data['resident_resort'] as String?)?.trim().isNotEmpty == true
              ? data['resident_resort'] as String
              : '暂无固定雪场';
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
        if (_residentRegion != null && _residentRegion!.isNotEmpty)
          'resident_region': _residentRegion,
        'resident_resort': _residentResort,
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

      final nickname = updates['nickname'] as String?;
      if (nickname != null && nickname.trim().isNotEmpty) {
        await ProfileSyncService().updateNickname(nickname);
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
      appBar: AppBar(title: const Text('编辑资料')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppField(
              label: '昵称',
              requiredMark: true,
              child: AppTextField(
                controller: _usernameController,
                hint: '你的雪友昵称',
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            AppField(
              label: '个性签名',
              child: AppTextField(
                controller: _introController,
                hint: '一句话介绍',
                minLines: 3,
                maxLines: 4,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '常驻地区',
              child: RegionField(
                region: _residentRegion ?? '',
                resort: _residentResort,
                onChanged: (selection) => setState(() {
                  _residentRegion = selection.region;
                  _residentResort = selection.resort;
                }),
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            AppField(
              label: '头像',
              child: Row(
                children: [
                  _pickedAvatar != null
                      ? ClipOval(
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: _pickedAvatar!.bytes != null
                                ? Image.memory(
                                    _pickedAvatar!.bytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_pickedAvatar!.path!),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        )
                      : AppAvatar(url: _avatarUrl, size: 72),
                  const SizedBox(width: AppSpace.lg),
                  AppButton(
                    label: '选择头像',
                    variant: AppButtonVariant.outline,
                    dense: true,
                    onPressed: _pickAvatar,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            AppField(
              label: '背景图',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      height: 104,
                      width: double.infinity,
                      child: _pickedCover != null
                          ? (_pickedCover!.bytes != null
                                ? Image.memory(
                                    _pickedCover!.bytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_pickedCover!.path!),
                                    fit: BoxFit.cover,
                                  ))
                          : (_coverUrl != null && _coverUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _coverUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: context.colors.soft),
                                    errorWidget: (context, url, error) =>
                                        Container(color: context.colors.soft),
                                  )
                                : Container(color: context.colors.soft)),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  AppButton(
                    label: '选择背景图',
                    variant: AppButtonVariant.outline,
                    dense: true,
                    onPressed: _pickCover,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xxl),

            AppButton(
              label: '保存',
              expand: true,
              loading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
