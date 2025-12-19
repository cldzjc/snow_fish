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
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
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
        _locationController.text.isEmpty) {
      _showSnackbar('请填写所有必填信息', Colors.orange);
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
          'title': _titleController.text,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'image':
              'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/500/600',
          'location': _locationController.text,
          'selleravatar': // 保持一致的字段名
              'https://api.dicebear.com/7.x/avataaars/svg?seed=NewUser',
          'sellername': '新用户-${DateTime.now().millisecond}', // 保持一致的字段名
        });
      } else {
        // Supabase 模式：使用 ProductService
        print('开始发布商品到 Supabase...');
        final result = await ProductService().createProduct(
          title: _titleController.text,
          price: double.tryParse(_priceController.text) ?? 0.0,
          location: _locationController.text,
          sellerName: '新用户-${DateTime.now().millisecond}',
          sellerAvatar:
              'https://api.dicebear.com/7.x/avataaars/svg?seed=NewUser',
          image:
              'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/500/600',
          // 新增字段暂时使用默认值
          category: '其他',
          condition: '九成新',
          description: '商品描述：${_titleController.text}',
          brand: null,
          size: null,
          usageTime: '使用半年',
          transactionMethods: '当面交易',
          negotiable: false,
        );
        print('发布成功，返回的商品数据: $result');
      }

      // 清空表单
      _titleController.clear();
      _priceController.clear();
      _locationController.clear();

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
              '商品信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 标题输入
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '商品标题 (必填)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            // 价格输入
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '价格 (元, 必填)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 16),

            // 地点输入
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '交易地点 (必填)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
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
}
