import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'supabase_client.dart';

// 商品服务类，统一管理商品的数据操作
class ProductService {
  static final SupabaseClient _client = SupabaseClientManager.instance;

  // 获取商品列表流 (使用 realtime)
  Stream<List<Map<String, dynamic>>> getProductsStream() {
    return _client
        .from('products')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((event) => event as List<Map<String, dynamic>>);
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

  // 发布新商品
  Future<Map<String, dynamic>> createProduct({
    required String title,
    required double price,
    required String location,
    required String sellerName,
    required String sellerAvatar,
    required String image,
    String? userId,
    // 新增可选字段
    String? category,
    String? condition,
    String? description,
    String? brand,
    String? size,
    String? usageTime,
    String? transactionMethods,
    bool? negotiable,
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
        // 新增字段
        'category': category,
        'condition': condition,
        'description': description,
        'brand': brand,
        'size': size,
        'usage_time': usageTime, // 匹配数据库字段名
        'transaction_methods': transactionMethods, // 匹配数据库字段名
        'negotiable': negotiable,
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
}
