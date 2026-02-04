import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../config.dart';
import '../services/entity_service.dart';
import '../media_service.dart';
import 'login_page.dart';

class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _titleController = TextEditingController(); // 商品标题
  final _contentController = TextEditingController(); // 正文内容
  final _priceController = TextEditingController(); // 价格
  List<PlatformFile> _pickedImages = []; // 选中的图片文件
  PlatformFile? _pickedVideo; // 选中的视频文件
  bool _isLoading = false;

  // 检查登录状态
  bool _isLoggedIn() {
    return Supabase.instance.client.auth.currentSession != null;
  }

  // 核心功能：发布商品
  Future<void> _publishProduct() async {
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
        _showSnackbar('需要登录后才能发布商品', Colors.orange);
        return;
      }
    }

    if (_titleController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _pickedImages.isEmpty) {
      _showSnackbar('请填写标题、价格并选择图片', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (USE_LOCAL_DATA) {
        // 本地模式：写入内存列表
        final id = 'local-${DateTime.now().millisecondsSinceEpoch}';
        localProducts.insert(0, {
          'id': id,
          'title': _titleController.text, // 使用标题字段
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'image': _pickedImages.isNotEmpty
              ? 'local-image-${_pickedImages.length}'
              : null,
          'location': '未知地点', // 简化为默认值
          'selleravatar':
              'https://api.dicebear.com/7.x/avataaars/svg?seed=NewUser',
          'sellername': '新用户-${DateTime.now().millisecond}',
          'description': _contentController.text, // 正文作为描述
        });

        // 本地发布成功，关闭页面并返回 true
        if (mounted) Navigator.pop(context, true);
        return;
      } else {
        // Supabase 模式：使用 EntityService
        print('开始发布商品到 Supabase...');
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) {
          _showSnackbar('未登录，无法发布', Colors.red);
          return;
        }

        // 获取用户资料（用于获取真实昵称和头像）
        print('📋 查询用户资料: ${currentUser.id}');
        final userProfile = await Supabase.instance.client
            .from('user_profiles')
            .select()
            .eq('id', currentUser.id)
            .maybeSingle();

        print('📋 用户资料查询结果: $userProfile');

        final sellerName =
            (userProfile?['nickname'] as String?) ??
            (currentUser.userMetadata?['name'] as String?) ??
            currentUser.email ??
            '用户';

        final sellerAvatar =
            (userProfile?['avatar_url'] as String?) ??
            'https://api.dicebear.com/7.x/avataaars/svg?seed=${currentUser.id}';

        print('✅ 卖家信息: name=$sellerName, avatar=$sellerAvatar');

        try {
          // 1. 创建商品实体（使用 EntityService）
          final entity = await EntityService().createEntity(
            entityType: 'product',
            title: _titleController.text,
            content: _contentController.text,
            extraData: {
              'price': double.tryParse(_priceController.text) ?? 0.0,
              'location': '未知地点',
              'sellerName': sellerName,
              'sellerAvatar': sellerAvatar,
            },
          );
          print('发布成功，返回的实体数据: $entity');

          // 2. 上传媒体文件
          final mediaService = MediaService();

          // 上传图片
          if (_pickedImages.isNotEmpty) {
            print('🖼️ 开始上传 ${_pickedImages.length} 张图片');
            for (final imageFile in _pickedImages) {
              try {
                print('   上传图片: ${imageFile.name}');
                await mediaService.uploadMediaFile(
                  file: imageFile,
                  userId: currentUser.id,
                  entityId: entity.id,
                );
                print('   ✅ 图片上传成功');
              } catch (e) {
                print('   ❌ 上传图片失败: $e');
              }
            }
          }

          // 3. 如果有视频，上传视频
          if (_pickedVideo != null) {
            print('🎬 开始上传视频: ${_pickedVideo!.name}');
            try {
              await mediaService.uploadMediaFile(
                file: _pickedVideo!,
                userId: currentUser.id,
                entityId: entity.id,
              );
              print('   ✅ 视频上传成功');
            } catch (e) {
              print('   ❌ 上传视频失败: $e');
              // 检查是否是不支持的视频格式
              if (e is UnsupportedVideoException) {
                if (mounted) {
                  _showSnackbar(e.message, Colors.orange);
                }
                return; // 停止发布流程
              }
              // 其他错误继续抛出
              rethrow;
            }
          }

          // 发布成功后返回并通知刷新
          if (mounted) Navigator.pop(context, true);
          return;
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
        }
      }

      // 清空表单
      _titleController.clear();
      _contentController.clear();
      _priceController.clear();
      setState(() {
        _pickedImages = [];
        _pickedVideo = null;
      });

      _showSnackbar('商品发布成功！首页已实时更新', Colors.green);
    } catch (e) {
      _showSnackbar('发布失败: $e', Colors.red);
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
      compressionQuality: 100, // 不压缩，我们将手动压缩
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedImages = result.files;
      });
    }
  }

  // 选择视频
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedVideo = result.files.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '发布闲置',
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
              '发布商品',
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

            // 1.5 视频选择
            const Text(
              '选择视频 (可选)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _pickedVideo != null
                  ? Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.videocam,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pickedVideo!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${(_pickedVideo!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _pickedVideo = null;
                            });
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: _pickVideo,
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_camera_back,
                              size: 24,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '点击选择视频',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // 2. 标题输入
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '商品标题 (必填)',
                border: OutlineInputBorder(),
                hintText: '输入商品标题...',
              ),
            ),
            const SizedBox(height: 16),

            // 3. 正文输入
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '商品描述 (可选)',
                border: OutlineInputBorder(),
                hintText: '描述你的商品...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // 3. 价格输入
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '价格 (元, 必填)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 30),

            // 发布按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _publishProduct,
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
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _isLoading ? '发布中...' : '确认发布',
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
    _priceController.dispose();
    super.dispose();
  }
}
