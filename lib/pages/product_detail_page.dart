import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'home_page.dart'; // 导入 Product 类的定义

class ProductDetailPage extends StatelessWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 可折叠的头部，显示大图
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                product.title,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 5.0, color: Colors.black)],
                ),
              ),
              centerTitle: true,
              background: CachedNetworkImage(
                imageUrl: product.image,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
          // 商品详细信息内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¥${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),

                  // 商品详细信息
                  if (product.category != null ||
                      product.brand != null ||
                      product.condition != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "商品信息",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (product.category != null)
                              _buildInfoChip("分类", product.category!),
                            if (product.brand != null)
                              _buildInfoChip("品牌", product.brand!),
                            if (product.condition != null)
                              _buildInfoChip("成色", product.condition!),
                            if (product.size != null)
                              _buildInfoChip("尺寸", product.size!),
                            if (product.usageTime != null)
                              _buildInfoChip("使用情况", product.usageTime!),
                            if (product.negotiable == true)
                              _buildInfoChip("价格", "可议价", Colors.green[100]!),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // 交易信息
                  if (product.transactionMethods != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "交易方式",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.transactionMethods!,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(product.sellerAvatar),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.sellerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "商品 ID: ${product.id.substring(0, 8)}...",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "商品描述",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description ??
                        "这是一段关于 ${product.title} 的详细描述。现在您可以从发布页面添加新商品，它们会实时显示在这里。\n\n- 这是从数据库加载的商品，真实可靠。\n- 欢迎联系卖家：${product.sellerName}。",
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // 模拟聊天功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已向卖家发起私聊 (功能待实现)')),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("聊一聊"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // 模拟购买功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已加入购物车 (功能待实现)')),
                  );
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text("购买"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 信息标签组件
  Widget _buildInfoChip(String label, String value, [Color? backgroundColor]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}
