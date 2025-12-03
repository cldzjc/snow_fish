import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config.dart';

class PublishPage extends StatefulWidget {
  final bool isFirebaseReady;
  const PublishPage({super.key, required this.isFirebaseReady});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;

  // 获取 Firestore 集合的路径
  CollectionReference<Map<String, dynamic>> get productsCollection {
    // 遵循 Firestore 公共数据存储规则: /artifacts/{appId}/public/data/{your_collection_name}
    return FirebaseFirestore.instance
        .collection('artifacts')
        .doc('default-app-id')
        .collection('public')
        .doc('data')
        .collection('products');
  }

  // 核心功能：上传数据到 Firestore
  Future<void> _publishProduct() async {
    if (!widget.isFirebaseReady && !USE_LOCAL_DATA) {
      _showSnackbar('数据库未初始化，无法发布', Colors.red);
      return;
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
      final newProduct = {
        'title': _titleController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'location': _locationController.text,
        // 使用固定的虚拟卖家信息，实际应用中应使用真实用户数据
        'sellerName': '新用户-${DateTime.now().millisecond}',
        'sellerAvatar':
            'https://api.dicebear.com/7.x/avataaars/svg?seed=NewUser',
        'image':
            'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/500/600',
        'timestamp': FieldValue.serverTimestamp(), // 记录发布时间
      };

      if (USE_LOCAL_DATA) {
        // 本地模式：写入内存列表（home_page 读取同一列表）
        // 生成一个 id
        final id = 'local-${DateTime.now().millisecondsSinceEpoch}';
        localProducts.insert(0, {
          'id': id,
          'title': newProduct['title'],
          'price': newProduct['price'],
          'image': newProduct['image'],
          'location': newProduct['location'],
          'sellerAvatar': newProduct['sellerAvatar'],
          'sellerName': newProduct['sellerName'],
        });
      } else {
        await productsCollection.add(newProduct);
      }

      // 清空表单
      _titleController.clear();
      _priceController.clear();
      _locationController.clear();

      _showSnackbar('商品发布成功！首页已实时更新', Colors.green);
    } catch (e) {
      _showSnackbar('发布失败: $e', Colors.red);
      print('Firestore Error: $e');
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
