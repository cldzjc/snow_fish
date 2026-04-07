import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/base_entity.dart';
import '../models/media_model.dart';
import 'image_gallery_page.dart';
import 'video_player_page.dart';
import '../media_service.dart';
import '../services/entity_service.dart';
import '../services/comment_service.dart';
import '../widgets/comment_item.dart';
import '../widgets/comment_input_sheet.dart';
import '../models/comment_model.dart';

class ProductDetailPage extends StatefulWidget {
  final BaseEntity product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final MediaService _mediaService = MediaService();
  final EntityService _entityService = EntityService();
  final CommentService _commentService = CommentService();

  List<MediaModel> _allMedia = [];
  List<CommentModel> _comments = [];
  bool _isLoadingMedia = true;
  bool _isLoadingComments = true;
  int _hangCount = 0;
  int _laCount = 0;
  bool _userHanged = false;
  bool _userLaed = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadProductMedia();
    _loadProductStats();
    _loadComments();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProductMedia() async {
    try {
      final mediaList = await _mediaService.getMediaByEntity(widget.product.id);
      setState(() {
        _allMedia = mediaList;
        _isLoadingMedia = false;
      });
    } catch (e) {
      setState(() {
        _allMedia = [];
        _isLoadingMedia = false;
      });
    }
  }

  Future<void> _loadProductStats() async {
    try {
      final stats = await _entityService.getVoteStats(widget.product.id);
      final userHang = await _entityService.hasVoted(
        entityId: widget.product.id,
        score: 5,
      );
      final userLa = await _entityService.hasVoted(
        entityId: widget.product.id,
        score: 1,
      );

      setState(() {
        _hangCount = stats['like_count'] ?? 0;
        _laCount = stats['dislike_count'] ?? 0;
        _userHanged = userHang;
        _userLaed = userLa;
      });
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getCommentTree(
        entityId: widget.product.id,
      );
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _toggleHang() async {
    try {
      await _entityService.toggleVote(entityId: widget.product.id, score: 5);
      await _loadProductStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _toggleLa() async {
    try {
      await _entityService.toggleVote(entityId: widget.product.id, score: 1);
      await _loadProductStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  void _showCommentInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentInputSheet(
        entityId: widget.product.id,
        onCommentSubmitted: (comment) {
          _loadComments();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openImageGallery(int initialIndex) {
    final imageUrls = _allMedia
        .where((m) => m.mediaType == 'image')
        .map((m) => m.url)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryPage(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          title: widget.product.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 提取价格、位置等信息
    final price = widget.product.extraData['price'] ?? 0;
    final location = widget.product.extraData['location'] ?? '未知';
    final sellerName = widget.product.extraData['seller_name'] ?? '未知卖家';
    final sellerAvatar =
        widget.product.extraData['seller_avatar'] ??
        'https://api.dicebear.com/7.x/avataaars/svg?seed=${widget.product.id}';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部媒体轮播（图片+视频混合）
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _isLoadingMedia
                  ? Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : _allMedia.isEmpty
                  ? Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.image, size: 64)),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _allMedia.length,
                      itemBuilder: (context, index) {
                        final media = _allMedia[index];
                        if (media.mediaType == 'image') {
                          return GestureDetector(
                            onTap: () => _openImageGallery(index),
                            child: CachedNetworkImage(
                              imageUrl: media.url,
                              fit: BoxFit.contain,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[200]),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          );
                        } else {
                          // 视频
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerPage(url: media.url),
                              ),
                            ),
                            child: Container(
                              color: Colors.black,
                              child: const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_fill,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
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
                  // 价格
                  Text(
                    '¥${price.toString()}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 卖家信息
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(sellerAvatar),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '卖家',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 标题
                  Text(
                    widget.product.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 位置
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 夯/拉 操作栏
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: _toggleHang,
                          child: Row(
                            children: [
                              Icon(
                                _userHanged
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                color: _userHanged
                                    ? Colors.blue
                                    : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '夯',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _userHanged
                                      ? Colors.blue
                                      : Colors.grey[600],
                                ),
                              ),
                              if (_hangCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '+$_hangCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey[300],
                        ),
                        GestureDetector(
                          onTap: _toggleLa,
                          child: Row(
                            children: [
                              Icon(
                                _userLaed
                                    ? Icons.thumb_down
                                    : Icons.thumb_down_outlined,
                                color: _userLaed
                                    ? Colors.orange
                                    : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '拉',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _userLaed
                                      ? Colors.orange
                                      : Colors.grey[600],
                                ),
                              ),
                              if (_laCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '+$_laCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),

                  // 商品描述
                  const Text(
                    "商品描述",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.content ?? '暂无描述',
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),

                  // 评论区
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '评论 (${_comments.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showCommentInput,
                        icon: const Icon(Icons.add_comment, size: 18),
                        label: const Text('写评论'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 评论列表
                  if (_isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          '暂无评论，快来抢沙发吧~',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        return CommentItem(
                          comment: _comments[index],
                          onReplyPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => CommentInputSheet(
                                entityId: widget.product.id,
                                replyTo: _comments[index],
                                onCommentSubmitted: (newComment) {
                                  _loadComments();
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                          onDeleted: (deletedComment) {
                            _loadComments();
                          },
                          onLikeChanged: () {
                            _loadComments();
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
