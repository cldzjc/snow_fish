import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'home_page.dart'; // 导入 Product 类的定义
import 'image_gallery_page.dart';
import 'video_player_page.dart';
import '../media_service.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final MediaService _mediaService = MediaService();
  List<String> _imageUrls = [];
  List<String> _videoUrls = []; // 新增：视频URL列表
  bool _isLoadingImages = true;
  int _currentImageIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadProductImages();
    _loadProductVideos(); // 新增：加载视频
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProductImages() async {
    try {
      final mediaList = await _mediaService.getMediaByEntity(widget.product.id);

      final urls = mediaList.map((media) => media.url).toList();

      setState(() {
        _imageUrls = urls.isNotEmpty
            ? urls
            : (widget.product.image != null ? [widget.product.image!] : []);
        _isLoadingImages = false;
      });
    } catch (e) {
      // 如果加载失败，使用默认图片
      setState(() {
        _imageUrls = widget.product.image != null
            ? [widget.product.image!]
            : [];
        _isLoadingImages = false;
      });
    }
  }

  Future<void> _loadProductVideos() async {
    try {
      final mediaList = await _mediaService.getMediaByEntity(widget.product.id);

      final videoUrls = mediaList
          .where((media) => media.mediaType == 'video')
          .map((media) => media.url)
          .toList();

      setState(() {
        _videoUrls = videoUrls;
      });
    } catch (e) {
      // 加载失败就算了，不影响主流程
    }
  }

  void _openImageGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryPage(
          imageUrls: _imageUrls,
          initialIndex: initialIndex,
          title: widget.product.title,
        ),
      ),
    );
  }

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
                widget.product.title,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 5.0, color: Colors.black)],
                ),
              ),
              centerTitle: true,
              background: GestureDetector(
                onTap: () => _openImageGallery(_currentImageIndex),
                child: _isLoadingImages
                    ? Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : _imageUrls.length > 1
                    ? PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemCount: _imageUrls.length,
                        itemBuilder: (context, index) {
                          return CachedNetworkImage(
                            imageUrl: _imageUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          );
                        },
                      )
                    : CachedNetworkImage(
                        imageUrl: _imageUrls.isNotEmpty
                            ? _imageUrls[0]
                            : widget.product.image ??
                                  'https://picsum.photos/seed/placeholder/500/500',
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
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
                    '¥${widget.product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product.title,
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
                        widget.product.location,
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

                  // 多图展示区域
                  if (!_isLoadingImages && _imageUrls.length > 1)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "商品图片",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageUrls.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => _openImageGallery(index),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: index == _currentImageIndex
                                          ? Colors.blue
                                          : Colors.grey[300]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(
                                      imageUrl: _imageUrls[index],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // 商品详细信息
                  if (widget.product.media.isNotEmpty)
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
                            _buildInfoChip("类型", widget.product.entityType),
                            if (widget.product.location.isNotEmpty)
                              _buildInfoChip("位置", widget.product.location),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // 新增：视频展示区域
                  if (_videoUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "商品视频",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _videoUrls.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VideoPlayerPage(url: _videoUrls[index]),
                              ),
                            ),
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 现在不做缩略图，先用默认封面
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.play_circle_fill,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(
                                      Icons.videocam,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(
                          widget.product.sellerAvatar ??
                              'https://api.dicebear.com/7.x/avataaars/svg?seed=${widget.product.id}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.sellerName ?? '未知卖家',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '卖家',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
                    widget.product.description,
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
