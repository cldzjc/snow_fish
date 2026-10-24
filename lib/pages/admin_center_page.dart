import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/base_entity.dart';
import '../services/entity_service.dart';

class AdminCenterPage extends StatefulWidget {
  const AdminCenterPage({super.key});

  @override
  State<AdminCenterPage> createState() => _AdminCenterPageState();
}

class _AdminCenterPageState extends State<AdminCenterPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final EntityService _entityService = EntityService();

  late Future<List<Map<String, dynamic>>> _futureUsers;
  late Future<List<BaseEntity>> _futurePendingProducts;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _futureUsers = _loadUsers();
    _futurePendingProducts = _loadPendingProducts();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final response = await _client
        .from('user_profiles')
        .select()
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<BaseEntity>> _loadPendingProducts() async {
    final products = await _entityService.fetchEntities(
      type: 'product',
      limit: 100,
    );
    return products.where((item) => item.auditStatus != 'approved').toList();
  }

  Future<void> _updateUserRole(String userId, String role) async {
    try {
      await _client
          .from('user_profiles')
          .update({'role': role})
          .eq('id', userId);
      if (!mounted) return;
      setState(_refreshData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已更新用户身份为：$role')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('身份更新失败: $e')));
    }
  }

  Future<void> _approveProduct(BaseEntity product) async {
    try {
      await _entityService.updateEntityExtraData(
        entityId: product.id,
        extraDataUpdates: {'audit_status': 'approved', 'is_hidden': false},
      );
      if (!mounted) return;
      setState(_refreshData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('审核通过：${product.title}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('审核失败: $e')));
    }
  }

  Future<void> _rejectProduct(BaseEntity product) async {
    try {
      await _entityService.updateEntityExtraData(
        entityId: product.id,
        extraDataUpdates: {'audit_status': 'rejected'},
      );
      if (!mounted) return;
      setState(_refreshData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('审核拒绝：${product.title}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('审核失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('审核中心')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_refreshData);
          await Future.wait([_futureUsers, _futurePendingProducts]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSectionTitle('用户身份管理（仅 user/admin）'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureUsers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('暂无用户资料'),
                  );
                }
                return Column(
                  children: users.take(10).map(_buildUserCard).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('待审核商品（卡片审核）'),
            FutureBuilder<List<BaseEntity>>(
              future: _futurePendingProducts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('暂无待审核商品'),
                  );
                }
                return Column(
                  children: products
                      .map((item) => _buildProductCard(item, label: '闲置商品'))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.orange.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '管理员卡片审核台',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text('用于商品审核与用户身份管理。', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['id'] as String? ?? '';
    final nickname = user['nickname'] as String? ?? '未命名用户';
    final role = user['role'] as String? ?? 'user';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('用户ID：$userId'),
            const SizedBox(height: 4),
            Text('当前身份：$role'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _updateUserRole(userId, 'user'),
                  child: const Text('设为普通用户'),
                ),
                ElevatedButton(
                  onPressed: () => _updateUserRole(userId, 'admin'),
                  child: const Text('设为管理员'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BaseEntity product, {required String label}) {
    final auditLabel = switch (product.auditStatus) {
      'approved' => '已通过',
      'pending_review' => '待审核',
      'pending' => '待审核',
      'rejected' => '未通过',
      _ => product.auditStatus,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('作者ID：${product.userId}'),
            const SizedBox(height: 4),
            Text('类型：$label'),
            const SizedBox(height: 4),
            Text('审核状态：$auditLabel'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveProduct(product),
                    child: const Text('通过'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectProduct(product),
                    child: const Text('拒绝'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
