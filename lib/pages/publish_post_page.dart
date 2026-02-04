import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../services/entity_service.dart';
import '../media_service.dart';
import 'login_page.dart';

class PublishPostPage extends StatefulWidget {
  const PublishPostPage({super.key});

  @override
  State<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends State<PublishPostPage> {
  final _titleController = TextEditingController(); // 帖子标题（可选）
  final _contentController = TextEditingController(); // 正文内容（必填）
  List<PlatformFile> _pickedImages = []; // 选中的图片文件
  bool _isLoading = false;

  // 检查登录状态
  bool _isLoggedIn() {
    return Supabase.instance.client.auth.currentSession != null;
  }

  // 核心功能：发布帖子
  Future<void> _publishPost() async {
    // 先检查登录状态
    if (!_isLoggedIn()) {
      // 未登录，跳转到登录页
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      // 登录成功后返回，检查是否现在已登录
      if (!_isLoggedIn()) {
        // 如果还是未登录，说明用户取消了登录
        _showSnackbar('需要登录后才能发布帖子', Colors.orange);
        return;
      }
    }

    if (_contentController.text.isEmpty) {
      _showSnackbar('请输入帖子内容', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 创建帖子实体（使用 EntityService）
      final currentUser = Supabase.instance.client.auth.currentUser;

      final post = await EntityService().createEntity(
        entityType: 'post',
        title: _titleController.text.isEmpty ? '动态' : _titleController.text,
        content: _contentController.text,
        extraData: {},
      );

      // 2. 上传图片到帖子
      if (_pickedImages.isNotEmpty) {
        final mediaService = MediaService();
        for (final imageFile in _pickedImages) {
          try {
            await mediaService.uploadMediaFile(
              file: imageFile,
              userId: currentUser!.id,
              entityId: post.id,
            );
          } catch (e) {
            print('上传图片失败: $e');
            // 检查是否是不支持的视频格式
            if (e is UnsupportedVideoException) {
              _showSnackbar(e.message, Colors.orange);
              return;
            }
            rethrow;
          }
        }
      }

      // 3. 成功
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('network:')) {
        _showSnackbar('网络无法连接，发布失败，请检查网络', Colors.red);
      } else if (msg.contains('permission:')) {
        _showSnackbar('发布被拒绝（权限不足），请检查 Supabase RLS 策略', Colors.red);
      } else {
        _showSnackbar('发布失败: $e', Colors.red);
      }
      print('发布 Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 选择图片
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedImages = result.files;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '发布帖子',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '发布帖子',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 1. 图片选择
            const Text(
              '选择图片',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _pickedImages.isNotEmpty
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pickedImages.length,
                      itemBuilder: (context, index) {
                        final file = _pickedImages[index];
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: file.bytes != null
                                    ? Image.memory(
                                        file.bytes!,
                                        width: 104,
                                        height: 104,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(file.path!),
                                        width: 104,
                                        height: 104,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _pickedImages.removeAt(index);
                                  });
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : InkWell(
                      onTap: _pickImages,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 32,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '点击选择图片（支持多图）',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // 2. 标题输入（可选）
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '帖子标题 (可选)',
                border: OutlineInputBorder(),
                hintText: '输入帖子标题...',
              ),
            ),
            const SizedBox(height: 16),

            // 3. 正文输入（必填）
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '帖子内容 (必填)',
                border: OutlineInputBorder(),
                hintText: '分享你的想法...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 30),

            // 发布按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _publishPost,
                icon: _isLoading
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isLoading ? '发布中...' : '发布帖子',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
