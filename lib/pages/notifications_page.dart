import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_utils.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_state_views.dart';
import 'login_page.dart';
import 'post_detail_page.dart';

/// 底部导航红点监听的未读数量。
final ValueNotifier<int> notificationUnreadCount = ValueNotifier<int>(0);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 50;

  final SupabaseClient _client = Supabase.instance.client;
  final Set<String> _markedLocally = <String>{};

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
        _items = <Map<String, dynamic>>[];
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
        _markedLocally.clear();
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
      item['read_at'] == null && !_markedLocally.contains(item['id']);

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (!_isUnread(item)) return;
    try {
      await _client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': item['id']},
      );
      if (!mounted) return;
      setState(() => _markedLocally.add(item['id'] as String));
      final next = notificationUnreadCount.value - 1;
      notificationUnreadCount.value = next < 0 ? 0 : next;
    } catch (_) {
      // 标记失败不阻断后续跳转。
    }
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

  Future<void> _handleTap(Map<String, dynamic> item) async {
    await _markRead(item);
    final entityId = item['entity_id'] as String?;
    if (!mounted || entityId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: entityId)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(
            onPressed: _items.isEmpty ? null : _markAllRead,
            child: Text(
              '全部已读',
              style: AppText.bodySmall.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingSkeleton(rows: 3);
    if (_client.auth.currentUser == null) {
      return AppStateView.login(
        onLogin: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        ),
      );
    }
    if (_error != null) return AppStateView.error(onRetry: _load);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: const AppStateView(
          icon: AppIcons.bell,
          title: '暂时没有通知',
          description: '有人点赞、评论或回复你时，会出现在这里。',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _NotificationRow(
            item: item,
            unread: _isUnread(item),
            onTap: () => _handleTap(item),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.unread,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    final hasTarget = item['entity_id'] != null;

    return Semantics(
      button: true,
      label: unread ? '未读通知' : '已读通知',
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unread ? colors.ink : colors.soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.bell,
                  size: 18,
                  color: unread ? colors.paper : colors.muted,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '系统通知',
                      style: AppText.body.copyWith(
                        color: colors.ink,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      item['body']?.toString() ?? '',
                      style: AppText.bodySmall.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      [
                        unread ? '未读' : '已读',
                        if (createdAt != null)
                          TimeUtils.formatRelativeTime(createdAt),
                      ].join(' · '),
                      style: AppText.caption.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (hasTarget)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Icon(AppIcons.chevron, size: 18, color: colors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
