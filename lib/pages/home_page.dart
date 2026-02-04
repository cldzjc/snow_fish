import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_detail_page.dart';
import 'posts_list_widget.dart';
import 'publish_post_page.dart';
import 'publish_page.dart';
import '../config.dart';
import '../services/entity_service.dart';
import '../models/base_entity.dart';
import '../models/media_model.dart';

// 1. 商品数据模型 (来自 BaseEntity)
class Product {
  final String id;
  final String title;
  final double price;
  final String location;
  final String? image;
  final String? sellerAvatar;
  final String? sellerName;
  final String description;
  final String entityType;
  final List<MediaModel> media;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.location,
    this.image,
    this.sellerAvatar,
    this.sellerName,
    required this.description,
    required this.entityType,
    required this.media,
  });

  /// 从 BaseEntity 创建 Product
  factory Product.fromEntity(BaseEntity entity) {
    final price = (entity.extraData['price'] as num?)?.toDouble() ?? 0.0;
    final location = entity.extraData['location'] as String? ?? '未知地点';
    final sellerName = entity.extraData['sellerName'] as String? ?? '未知卖家';
    final sellerAvatar = entity.extraData['sellerAvatar'] as String?;
    final imageUrl = entity.media.isNotEmpty
        ? entity.media.first.url
        : 'https://picsum.photos/seed/placeholder/500/500';

    return Product(
      id: entity.id,
      title: entity.title,
      price: price,
      location: location,
      image: imageUrl,
      description: entity.content ?? '',
      entityType: entity.entityType,
      media: entity.media,
      sellerName: sellerName,
      sellerAvatar: sellerAvatar,
    );
  }
}

// 2. 首页组件（两分区：广场 + 雪具交易）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '广场'),
            Tab(text: '雪具交易'),
          ],
          labelColor: Colors.black,
          indicatorColor: Colors.blue,
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          PostsListWidget(), // 广场：帖子列表
          _buildProductList(), // 雪具交易：商品列表（原有逻辑）
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isPostsTab = _tabController.index == 0;
          return FloatingActionButton(
            onPressed: () async {
              if (isPostsTab) {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PublishPostPage()),
                );
                if (res == true) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('帖子发布成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PublishPage()),
                );
                if (res == true) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('商品发布成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            tooltip: isPostsTab ? '发布帖子' : '发布商品',
            child: Icon(isPostsTab ? Icons.create : Icons.add_box_outlined),
          );
        },
      ),
    );
  }

  Widget _buildProductList() {
    // 本地演示模式（可选）
    if (USE_LOCAL_DATA) {
      // 使用本地数据（如果需要）
      return const Center(child: Text('本地演示模式未实现'));
    }

    // 使用 EntityService 加载商品数据
    return FutureBuilder<List<BaseEntity>>(
      future: EntityService().fetchEntities(type: 'product', limit: 50),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final msg = snapshot.error?.toString() ?? '';
          String display = '加载失败，请检查网络连接';
          if (msg.contains('network:')) {
            display = '网络连接失败，请检查网络设置';
          } else if (msg.contains('permission:')) {
            display = '权限错误：无法加载商品';
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
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
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('正在加载商品...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final entities = snapshot.data ?? [];
        if (entities.isEmpty) {
          return const Center(child: Text('暂无商品发布'));
        }

        final products = entities.map((e) => Product.fromEntity(e)).toList();

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

  // 3. 商品卡片组件
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
            // 图片区域
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl:
                      product.image ??
                      'https://picsum.photos/seed/placeholder/500/500',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.error),
                  ),
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

                  // 价格和位置
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥${product.price.toStringAsFixed(0)}',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
