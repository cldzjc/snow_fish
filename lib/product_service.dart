import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'supabase_client.dart';
import 'media_service.dart';

// 商品服务类，统一管理商品的数据操作
class ProductService {
  static final SupabaseClient _client = SupabaseClientManager.instance;

  // 获取商品列表流 (使用 realtime，带错误处理)
  Stream<List<Map<String, dynamic>>> getProductsStream() {
    return _client
        .from('products')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((event) => List<Map<String, dynamic>>.from(event))
        .handleError((error) {
          print('Realtime Stream Error: $error');
          // 如果是超时错误，可以考虑重试或降级到普通查询
          if (error.toString().contains('timedOut') ||
              error.toString().contains('RealtimeSubscribeException')) {
            throw Exception('realtime_timeout: Realtime连接超时，请检查网络连接');
          }
          throw error;
        })
        .asBroadcastStream();
  }

  // 获取商品列表 (一次性查询)
  Future<List<Map<String, dynamic>>> getProductsList() async {
    try {
      final response = await _client
          .from('products')
          .select('*')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 获取单个商品详情
  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final response = await _client
          .from('products')
          .select('*')
          .eq('id', productId)
          .single();

      return response;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 发布新商品（简化版：只需标题、价格、图片、位置和描述）
  Future<Map<String, dynamic>> createProduct({
    required String title,
    required double price,
    required String location,
    required String sellerName,
    required String sellerAvatar,
    required String image,
    String? userId,
    String? description, // 商品描述（可选）
  }) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final newProduct = {
        'title': title,
        'price': price,
        'location': location,
        'sellername': sellerName, // 匹配数据库字段名
        'selleravatar': sellerAvatar, // 匹配数据库字段名
        'user_id': userId ?? currentUserId,
        'image': image,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        if (description != null) 'description': description,
      };

      final response = await _client
          .from('products')
          .insert(newProduct)
          .select();

      return response.first;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 删除商品
  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('id', productId);
  }

  // 更新商品
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _client.from('products').update(updates).eq('id', productId);
    } catch (e) {
      rethrow;
    }
  }

  // 方便切换本地数据和 Supabase 数据
  dynamic getProductsSource() {
    if (USE_LOCAL_DATA) {
      return localProducts;
    } else {
      return getProductsStream;
    }
  }

  // 获取当前用户发布的商品（一次性查询）
  Future<List<Map<String, dynamic>>> getProductsByUser(String userId) async {
    try {
      final response = await _client
          .from('products')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 获取带有图片的商品列表（从media表获取第一张图片）
  Future<List<Map<String, dynamic>>> getProductsWithImages() async {
    try {
      final products = await getProductsList();
      final mediaService = MediaService();

      // 为每个商品获取第一张图片
      for (var product in products) {
        try {
          final media = await mediaService.getMediaByOwner(
            ownerType: 'product',
            ownerId: product['id'].toString(),
          );

          // 如果有图片，使用第一张图片的URL
          if (media.isNotEmpty) {
            product['image'] = media.first['url'];
          } else {
            // 如果没有图片，使用默认占位图
            product['image'] = 'https://picsum.photos/seed/placeholder/500/500';
          }
        } catch (e) {
          // 如果获取图片失败，使用默认占位图
          product['image'] = 'https://picsum.photos/seed/placeholder/500/500';
        }
      }

      return products;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException')) {
        throw Exception('network: $e');
      }
      if (msg.contains('permission') ||
          msg.contains('403') ||
          msg.contains('forbidden') ||
          msg.contains('Unauthorized')) {
        throw Exception('permission: $e');
      }
      throw Exception('other: $e');
    }
  }

  // 获取带有图片的商品流（实时更新）
  Stream<List<Map<String, dynamic>>> getProductsWithImagesStream() {
    return _getProductsWithImagesStreamInternal().asBroadcastStream();
  }

  // 内部实现方法
  Stream<List<Map<String, dynamic>>>
  _getProductsWithImagesStreamInternal() async* {
    await for (final products in getProductsStream()) {
      final mediaService = MediaService();

      // 为每个商品获取第一张图片
      for (var product in products) {
        try {
          final media = await mediaService.getMediaByOwner(
            ownerType: 'product',
            ownerId: product['id'].toString(),
          );

          // 如果有图片，使用第一张图片的URL
          if (media.isNotEmpty) {
            product['image'] = media.first['url'];
          } else {
            // 如果没有图片，使用默认占位图
            product['image'] = 'https://picsum.photos/seed/placeholder/500/500';
          }
        } catch (e) {
          // 如果获取图片失败，使用默认占位图
          product['image'] = 'https://picsum.photos/seed/placeholder/500/500';
        }
      }

      yield products;
    }
  }
}
