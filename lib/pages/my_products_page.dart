import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/entity_service.dart';
import '../models/base_entity.dart';
import 'product_detail_page.dart';
import 'login_page.dart';

class MyProductsPage extends StatefulWidget {
  const MyProductsPage({super.key});

  @override
  State<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends State<MyProductsPage> {
  late final Future<List<BaseEntity>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _futureProducts = _loadProductsForCurrentUser();
  }

  Future<List<BaseEntity>> _loadProductsForCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('not_logged_in');
    }

    final entities = await EntityService().fetchUserEntities(
      userId: user.id,
      type: 'product',
    );
    return entities;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我发布的商品'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: FutureBuilder<List<BaseEntity>>(
        future: _futureProducts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final err = snapshot.error;
            final msg = err?.toString() ?? '';
            if (msg.contains('not_logged_in')) {
              return _buildNotLoggedIn();
            }

            String display = '加载失败，请检查网络或稍后重试';
            if (msg.contains('network:')) {
              display = '网络连接失败，请检查模拟器网络设置';
            } else if (msg.contains('permission:')) {
              display = '权限错误：无法读取您的商品，可能需要检查 Supabase RLS 策略';
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
                      onPressed: () {
                        setState(() {
                          _futureProducts = _loadProductsForCurrentUser();
                        });
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Center(child: Text('您还没有发布任何商品'));
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
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, BaseEntity product) {
    // 基于 HomePage 中的卡片样式复用实现（复制但保持视觉一致）
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl:
                      (product.media.isNotEmpty
                          ? product.media.first.url
                          : null) ??
                      'https://picsum.photos/seed/placeholder/500/500',
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
                        '¥${(product.price ?? 0).toString()}',
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
                            product.location ?? '未知',

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
                        backgroundImage: NetworkImage(
                          (product.extraData['seller_avatar'] as String?) ??
                              'https://picsum.photos/seed/avatar/200/200',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (product.extraData['seller_name'] as String?) ?? '未知卖家',
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

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请先登录以查看您发布的商品', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                setState(() {
                  _futureProducts = _loadProductsForCurrentUser();
                });
              },
              child: const Text('前往登录'),
            ),
          ],
        ),
      ),
    );
  }
}
