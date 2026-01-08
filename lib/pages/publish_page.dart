import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../product_service.dart';
import 'login_page.dart';

class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _contentController = TextEditingController(); // 正文内容
  final _priceController = TextEditingController(); // 价格
  String? _selectedImage; // 选中的图片URL

  bool _isLoading = false;

  // 预设图片选项（简化版，实际可以做图片上传）
  final List<String> _presetImages = [
    'https://picsum.photos/400/300?random=1',
    'https://picsum.photos/400/300?random=2',
    'https://picsum.photos/400/300?random=3',
    'https://picsum.photos/400/300?random=4',
    'https://picsum.photos/400/300?random=5',
    'https://picsum.photos/400/300?random=6',
  ];

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

    if (_contentController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedImage == null) {
      _showSnackbar('请填写正文、价格并选择图片', Colors.orange);
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
          'title': _contentController.text.length > 20
              ? '${_contentController.text.substring(0, 20)}...'
              : _contentController.text, // 正文作为标题
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'image': _selectedImage,
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
        // Supabase 模式：使用 ProductService
        print('开始发布商品到 Supabase...');
        final currentUser = Supabase.instance.client.auth.currentUser;
        final sellerName =
            (currentUser?.userMetadata?['name'] as String?) ??
            (currentUser?.userMetadata?['nickname'] as String?) ??
            currentUser?.email ??
            '用户';
        final sellerAvatar = currentUser != null
            ? 'https://api.dicebear.com/7.x/avataaars/png?seed=${currentUser.id}'
            : 'https://api.dicebear.com/7.x/avataaars/png?seed=NewUser';

        try {
          final result = await ProductService().createProduct(
            title: _contentController.text.length > 20
                ? '${_contentController.text.substring(0, 20)}...'
                : _contentController.text, // 正文前20字作为标题
            price: double.tryParse(_priceController.text) ?? 0.0,
            location: '未知地点', // 简化版本，固定值
            sellerName: sellerName,
            sellerAvatar: sellerAvatar,
            image: _selectedImage!, // 用户选择的图片
            description: _contentController.text, // 正文作为描述
          );
          print('发布成功，返回的商品数据: $result');

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
      _contentController.clear();
      _priceController.clear();
      setState(() {
        _selectedImage = null;
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
              child: _selectedImage != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _selectedImage!,
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 4)],
                            ),
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: () {
                        // 显示图片选择对话框
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('选择图片'),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 200,
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: _presetImages.length,
                                itemBuilder: (context, index) {
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedImage = _presetImages[index];
                                      });
                                      Navigator.of(context).pop();
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _presetImages[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('取消'),
                              ),
                            ],
                          ),
                        );
                      },
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
                              '点击选择图片',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // 2. 正文输入
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '正文内容 (必填)',
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
    _contentController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
