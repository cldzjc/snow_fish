import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'product_detail_page.dart';
import '../config.dart';

// 1. 商品数据模型 (现在可以接收 Firestore Document)
class Product {
  final String id;
  final String title;
  final double price;
  final String image;
  final String location;
  final String sellerAvatar;
  final String sellerName;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.image,
    required this.location,
    required this.sellerAvatar,
    required this.sellerName,
  });

  // 从 Firestore Document 映射到 Product 对象
  // 使用带泛型的 DocumentSnapshot 并对 data() 做空保护
  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Product(
      id: doc.id,
      title: data['title'] ?? '未知商品',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      image: data['image'] ?? 'https://picsum.photos/seed/placeholder/500/500',
      location: data['location'] ?? '未知地点',
      sellerAvatar:
          data['sellerAvatar'] ??
          'https://api.dicebear.com/7.x/avataaars/svg?seed=Default',
      sellerName: data['sellerName'] ?? '匿名用户',
    );
  }
}

// 2. 首页组件（改为 Stateful 支持重试）
class HomePage extends StatefulWidget {
  final bool isFirebaseReady;
  // 将 isFirebaseReady 设为可选，默认 true，兼容现有调用 HomePage()
  const HomePage({super.key, this.isFirebaseReady = true});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 用于触发 StreamBuilder 重建（重试）
  int _retryKey = 0;

  // 启动时对 Firestore 做一次性检测，避免无限等待
  bool _checkingConnection = true;
  String? _connectionError;

  // 当 Firebase 未初始化时，尝试初始化的状态
  bool _initAttempting = false;

  // 等待超时提示控制（在 stream 等待时提供额外提示）
  Timer? _waitingTimer;
  bool _showWaitingHint = false;

  @override
  void initState() {
    super.initState();
    // 如果启用了本地演示模式，直接跳过对 Firestore 的检测
    if (USE_LOCAL_DATA) {
      _checkingConnection = false;
      return;
    }

    if (widget.isFirebaseReady) {
      _checkFirestore();
      // 额外的防挂起回退：若在 6 秒内检测仍未结束，则显示可重试信息
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _checkingConnection) {
          setState(() {
            _checkingConnection = false;
            _connectionError = '检测超时（6s），可能网络或权限问题';
          });
        }
      });
    } else {
      // Firebase 未就绪，允许用户尝试初始化
      _checkingConnection = false;
    }
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    super.dispose();
  }

  // 当 Firebase 未初始化时，允许在页面内重试初始化（可在模拟器/真机上使用）
  Future<void> _tryInitFirebase() async {
    setState(() {
      _initAttempting = true;
      _connectionError = null;
      _checkingConnection = true;
    });
    try {
      await Firebase.initializeApp();
      // 初始化后再检测 Firestore 可用性
      await _checkFirestore();
    } catch (e) {
      // 打印并展示错误，便于调试
      debugPrint('Firebase init error: $e');
      if (mounted) {
        setState(() {
          _connectionError = e.toString();
          _checkingConnection = false;
        });
      }
    } finally {
      if (mounted) setState(() => _initAttempting = false);
    }
  }

  Future<void> _checkFirestore() async {
    setState(() {
      _checkingConnection = true;
      _connectionError = null;
    });
    try {
      // 尝试一次性读取以快速检测连接/权限问题
      await productsCollection
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        setState(() {
          _checkingConnection = false;
          _connectionError = null;
        });
      }
    } catch (e) {
      debugPrint('Firestore check error: $e');
      if (mounted) {
        setState(() {
          _checkingConnection = false;
          _connectionError = e.toString();
        });
      }
    }
  }

  // 获取 Firestore 集合的路径（保留泛型）
  CollectionReference<Map<String, dynamic>> get productsCollection {
    return FirebaseFirestore.instance
        .collection('artifacts')
        .doc('default-app-id')
        .collection('public')
        .doc('data')
        .collection('products');
  }

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
      body: widget.isFirebaseReady
          ? (_checkingConnection
                // 启动检测中：显示带说明的 loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('正在检测 Firestore 可用性...'),
                      ],
                    ),
                  )
                // 如果检测到错误，展示错误信息和重试
                : (_connectionError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '连接 Firestore 失败：\n$_connectionError',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '请检查网络、Firebase 配置或 Firestore 规则。',
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _checkFirestore,
                                  child: const Text('重试检测'),
                                ),
                              ],
                            ),
                          ),
                        )
                      // 检测通过：显示 stream
                      : _buildProductStream()))
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Firebase 未初始化。'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _initAttempting ? null : _tryInitFirebase,
                      child: _initAttempting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('初始化 Firebase 并检测'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator(color: Colors.blue));
  }

  Widget _buildProductStream() {
    // 本地演示模式：直接使用内存中示例数据，避免访问 Firebase
    if (USE_LOCAL_DATA) {
      final products = localProducts
          .map(
            (data) => Product(
              id: data['id'] as String,
              title: data['title'] as String,
              price: (data['price'] as num).toDouble(),
              image: data['image'] as String,
              location: data['location'] as String,
              sellerAvatar: data['sellerAvatar'] as String,
              sellerName: data['sellerName'] as String,
            ),
          )
          .toList();

      return MasonryGridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(context, product);
        },
      );
    }

    // 通过 timeout 防止无限等待；超时或其他错误时会走 snapshot.hasError 分支。
    final stream = productsCollection.snapshots().timeout(
      const Duration(seconds: 10),
      onTimeout: (sink) {
        // 抛出超时异常，StreamBuilder 会捕获并显示错误
        sink.addError(TimeoutException('获取数据超时，请检查网络或 Firebase 配置'));
      },
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey(_retryKey), // 重试时改变 key 强制重建
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 如果首次进入等待，启动一个定时器，超过一定时间后显示提示帮助排查
          _waitingTimer ??= Timer(const Duration(seconds: 8), () {
            if (mounted) setState(() => _showWaitingHint = true);
          });

          if (_showWaitingHint) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '正在连接 Firestore... 如果长时间未响应，请检查网络或 Firebase 配置。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        // 触发重试
                        setState(() {
                          _waitingTimer?.cancel();
                          _waitingTimer = null;
                          _showWaitingHint = false;
                          _retryKey++;
                        });
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          // 未超时前仍显示 loading
          return const Center(child: CircularProgressIndicator());
        } else {
          // 已收到事件或发生错误，取消等待计时器并重置提示状态
          if (_waitingTimer != null) {
            _waitingTimer?.cancel();
            _waitingTimer = null;
            if (_showWaitingHint && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _showWaitingHint = false);
              });
            }
          }
        }
        if (snapshot.hasError) {
          final msg = snapshot.error?.toString() ?? '未知错误';
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败：$msg', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    '提示：请检查 Firebase 配置、网络或模拟器网络设置，必要时在 main.dart 中使用 firebase_options 初始化。',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _retryKey++; // 触发重建并重试订阅
                      });
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              '暂无商品发布，点击“发布”按钮添加第一个商品吧！',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // 将 QuerySnapshot 转换为 Product 列表
        final products = snapshot.data!.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();

        return MasonryGridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(context, product);
          },
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
