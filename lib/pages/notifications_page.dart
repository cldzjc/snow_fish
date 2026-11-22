import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_detail_page.dart';

/// 全局未读数量，底部导航红点监听此值。
final ValueNotifier<int> notificationUnreadCount = ValueNotifier<int>(0);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const int _pageSize = 50;

  final _client = Supabase.instance.client;
  final Set<String> _readLocally = {};

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _error = null;
      });
      notificationUnreadCount.value = 0;
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(_pageSize);
      final unread = await _client.rpc('get_notification_unread_count');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
      notificationUnreadCount.value = unread is int
          ? unread
          : (unread as num?)?.toInt() ?? 0;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isUnread(Map<String, dynamic> item) =>
      item['read_at'] == null && !_readLocally.contains(item['id']);

  Future<void> _handleTap(Map<String, dynamic> item) async {
    final entityId = item['entity_id'] as String?;
    if (_isUnread(item)) {
      try {
        await _client.rpc(
          'mark_notification_read',
          params: {'p_notification_id': item['id']},
        );
        if (mounted) {
          setState(() => _readLocally.add(item['id'] as String));
        }
        notificationUnreadCount.value = math.max(
          0,
          notificationUnreadCount.value - 1,
        );
      } catch (_) {
        // 标记失败不阻塞跳转
      }
    }
    if (!mounted || entityId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: entityId)),
    );
  }

  Future<void> _markAllRead() async {
    try {
      await _client.rpc('mark_all_notifications_read');
      notificationUnreadCount.value = 0;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(onPressed: _markAllRead, child: const Text('全部已读')),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载通知失败'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暂无通知')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final item = _items[index];
          final unread = _isUnread(item);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: unread ? Colors.blue : Colors.grey,
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            title: Text(
              item['title'] as String? ?? '系统通知',
              style: TextStyle(
                fontWeight: unread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(item['body'] as String? ?? ''),
            trailing: item['entity_id'] == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: () => _handleTap(item),
          );
        },
      ),
    );
  }
}
