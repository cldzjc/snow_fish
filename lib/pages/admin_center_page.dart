import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_version.dart';
import '../services/moderation_service.dart';
import '../supabase_client.dart';

class AdminCenterPage extends StatefulWidget {
  const AdminCenterPage({super.key});

  @override
  State<AdminCenterPage> createState() => _AdminCenterPageState();
}

class _AdminCenterPageState extends State<AdminCenterPage> {
  final _service = ModerationService();
  late Future<List<Map<String, dynamic>>> _reports;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _reports = _service.loadOpenReports();

  Future<void> _resolve(Map<String, dynamic> report, String status) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'resolved' ? '确认违规并下架' : '无需处理'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '处理说明'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('提交'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    if (note.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写处理说明')));
      return;
    }
    try {
      await _service.resolveReport(
        reportId: report['id'] as String,
        status: status,
        note: note,
        targetType: report['target_type'] as String?,
        targetId: report['target_id'] as String?,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('举报已处理')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理失败：$e')));
    }
  }

  Future<void> setPinned(Map<String, dynamic> report, bool pinned) async {
    if (report['target_type'] != 'entity') return;
    final targetId = report['target_id'] as String?;
    if (targetId == null) return;
    try {
      await _service.setEntityPinned(
        entityId: targetId,
        pinned: pinned,
        until: pinned ? DateTime.now().add(const Duration(days: 7)) : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pinned ? '已置顶7天' : '已取消置顶')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('置顶操作失败：$e')));
    }
  }

  Future<void> _showBuildInfo() async {
    final now = DateTime.now();
    final host = Uri.tryParse(supabaseUrl)?.host ?? supabaseUrl;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('版本信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('版本号：$appVersion'),
            const SizedBox(height: 8),
            SelectableText('构建模式：${kReleaseMode ? 'Release' : 'Debug'}'),
            const SizedBox(height: 8),
            SelectableText('后端：$host'),
            const SizedBox(height: 8),
            SelectableText(
              '本机时间：${now.year}-${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 12),
            Text(
              appVersionNote,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容治理中心'),
        actions: [
          TextButton(
            onPressed: _showBuildInfo,
            child: Text('v$appVersion', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reports,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('无法加载举报：${snapshot.error}'));
            }
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return const Center(child: Text('暂无待处理举报'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  child: ListTile(
                    title: Text(_targetTitle(report)),
                    subtitle: Text(_targetDescription(report)),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'pin' || value == 'unpin') {
                          setPinned(report, value == 'pin');
                        } else {
                          _resolve(report, value);
                        }
                      },
                      itemBuilder: (context) => [
                        if (report['target_type'] == 'entity')
                          const PopupMenuItem(
                            value: 'pin',
                            child: Text('置顶7天'),
                          ),
                        if (report['target_type'] == 'entity')
                          const PopupMenuItem(
                            value: 'unpin',
                            child: Text('取消置顶'),
                          ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Text('确认违规并下架'),
                        ),
                        PopupMenuItem(value: 'dismissed', child: Text('无需处理')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _targetTitle(Map<String, dynamic> report) {
    final target = report['target'] as Map<String, dynamic>?;
    if (target == null) return '目标内容已不存在';
    if (report['target_type'] == 'entity') {
      final title = (target['title'] as String?)?.trim();
      return title == null || title.isEmpty ? '帖子' : title;
    }
    if (report['target_type'] == 'comment') {
      return '评论：${target['content'] ?? ''}';
    }
    return '用户：${target['nickname'] ?? '匿名用户'}';
  }

  String _targetDescription(Map<String, dynamic> report) {
    final target = report['target'] as Map<String, dynamic>?;
    return [
      '举报原因：${report['reason'] ?? '未填写'}',
      if ((report['details'] as String?)?.trim().isNotEmpty == true)
        '补充说明：${report['details']}',
      if (target != null && report['target_type'] == 'entity')
        '内容：${target['content'] ?? ''}',
      if (target == null) '目标 ID：${report['target_id']}',
    ].join('\n');
  }
}
