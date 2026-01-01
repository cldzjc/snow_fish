import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_detail_page.dart';
import '../config.dart';
import '../product_service.dart';

// 1. 商品数据模型 (支持完整 Supabase 数据)
class Product {
  final String id;
  final String title;
  final double price;
  final String image;
  final String location;
  final String sellerAvatar;
  final String sellerName;

  // 新增字段
  final String? category;
  final String? condition;
  final String? description;
  final String? brand;
  final String? size;
  final String? usageTime;
  final String? transactionMethods;
  final bool? negotiable;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.image,
    required this.location,
    required this.sellerAvatar,
    required this.sellerName,
    this.category,
    this.condition,
    this.description,
    this.brand,
    this.size,
    this.usageTime,
    this.transactionMethods,
    this.negotiable,
  });

  // 从 Map (Supabase 数据) 映射到 Product 对象
  factory Product.fromMap(Map<String, dynamic> data) {
    return Product(
      id: data['id']?.toString() ?? 'unknown',
      title: data['title'] ?? '未知商品',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      image: data['image'] ?? 'https://picsum.photos/seed/placeholder/500/500',
      location: data['location'] ?? '未知地点',
      sellerAvatar:
          data['selleravatar'] ??
          'https://api.dicebear.com/7.x/avataaars/svg?seed=Default',
      sellerName: data['sellername'] ?? '匿名用户',
      // 新增字段映射
      category: data['category'],
      condition: data['condition'],
      description: data['description'],
      brand: data['brand'],
      size: data['size'],
      usageTime: data['usage_time'], // 匹配数据库字段名
      transactionMethods: data['transaction_methods'], // 匹配数据库字段名
      negotiable: data['negotiable'] as bool?,
    );
  }
}

// 2. 首页组件（简化为使用 Supabase）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: '搜索品牌、型号...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _buildProductList(),
    );
  }

  Widget _buildProductList() {
    // 本地演示模式：直接使用内存中示例数据
    if (USE_LOCAL_DATA) {
      final products = localProducts
          .map((data) => Product.fromMap(data))
          .toList();

      return MasonryGridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: products.length,
        itemBuilder: (context, index) =>
            _buildProductCard(context, products[index]),
      );
    }

    // Supabase 模式：使用 Realtime 流
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ProductService().getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final msg = snapshot.error?.toString() ?? '';
          print('Supabase Stream Error: $msg'); // 添加调试信息

          String display = '加载失败，请检查网络连接';
          if (msg.contains('network:') ||
              msg.contains('Failed host lookup') ||
              msg.contains('SocketException')) {
            display = '网络连接失败，请检查模拟器或主机网络设置';
          } else if (msg.contains('permission:') ||
              msg.contains('403') ||
              msg.contains('forbidden')) {
            display = '权限错误：无法加载商品，请检查 Supabase RLS 策略';
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(display, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!
            .map((data) => Product.fromMap(data))
            .toList();

        if (products.isEmpty) {
          return const Center(child: Text('暂无商品发布'));
        }

        return MasonryGridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: products.length,
          itemBuilder: (context, index) =>
              _buildProductCard(context, products[index]),
        );
      },
    );
  }

  // 3. 商品卡片组件 (与之前逻辑相同，但现在使用 Product 对象)
  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域：为避免在 MasonryGrid 中尺寸不确定，增加高度约束
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: product.image,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),

            // 文本区域
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥${product.price.toStringAsFixed(0)}', // 格式化价格
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            '📍',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                          Text(
                            product.location,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundImage: NetworkImage(product.sellerAvatar),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.sellerName,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 174, 74, 74),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
