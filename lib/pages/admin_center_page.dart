import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_version.dart';
import '../services/moderation_service.dart';
import '../supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_sheet.dart';
import '../widgets/app/app_state_views.dart';

class AdminCenterPage extends StatefulWidget {
  const AdminCenterPage({super.key});

  @override
  State<AdminCenterPage> createState() => _AdminCenterPageState();
}

class _AdminCenterPageState extends State<AdminCenterPage> {
  static const String _dismiss = '无需处理';
  static const String _remove = '确认违规并下架';
  static const String _pin = '置顶 7 天';
  static const String _unpin = '取消置顶';

  final ModerationService _service = ModerationService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _service.loadOpenReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handle(Map<String, dynamic> report) async {
    final noteController = TextEditingController();
    String action = _remove;
    final targetType = report['target_type']?.toString() ?? '';
    final isEntity = targetType == 'entity';

    final options = <String>[
      _remove,
      _dismiss,
      if (isEntity) ...<String>[_pin, _unpin],
    ];

    final confirmed = await showAppSheet<bool>(
      context,
      title: '处理举报',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: '处理方式',
              requiredMark: true,
              child: AppDropdown<String>(
                options: [
                  for (final item in options) AppOption<String>(item, item),
                ],
                value: action,
                onChanged: (value) =>
                    setSheetState(() => action = value ?? _remove),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '处理说明',
              note: action == _pin || action == _unpin ? '置顶操作可不填' : '必填',
              child: AppTextField(
                controller: noteController,
                hint: '说明处理依据，会展示给举报人',
                minLines: 3,
                maxLines: 5,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            AppButton(
              label: '确认处理',
              expand: true,
              onPressed: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );

    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    if (action == _pin || action == _unpin) {
      final entityId = report['target_id'] as String?;
      if (entityId == null) return;
      try {
        await _service.setEntityPinned(
          entityId: entityId,
          pinned: action == _pin,
          until: action == _pin
              ? DateTime.now().add(const Duration(days: 7))
              : null,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$action 已完成')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('置顶操作失败：$e')));
      }
      return;
    }

    if (note.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写处理说明')));
      return;
    }

    try {
      await _service.resolveReport(
        reportId: report['id'] as String,
        status: action == _remove ? 'resolved' : 'dismissed',
        note: note,
        targetType: targetType,
        targetId: report['target_id'] as String?,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('举报已处理')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理失败：$e')));
    }
  }

  Future<void> _showBuildInfo() async {
    final now = DateTime.now();
    final host = Uri.tryParse(supabaseUrl)?.host ?? supabaseUrl;
    String two(int value) => value.toString().padLeft(2, '0');
    await showAppSheet<void>(
      context,
      title: '版本信息',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '版本号：$appVersion',
            style: AppText.body.copyWith(color: context.colors.ink),
          ),
          const SizedBox(height: AppSpace.md),
          SelectableText(
            '构建模式：${kReleaseMode ? 'Release' : 'Debug'}',
            style: AppText.bodySmall.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: AppSpace.sm),
          SelectableText(
            '后端：$host',
            style: AppText.bodySmall.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: AppSpace.sm),
          SelectableText(
            '本机时间：${now.year}-${two(now.month)}-${two(now.day)} '
            '${two(now.hour)}:${two(now.minute)}',
            style: AppText.bodySmall.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            appVersionNote,
            style: AppText.caption.copyWith(color: context.colors.muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容治理中心'),
        actions: [
          TextButton(
            onPressed: _showBuildInfo,
            child: Text(
              'v$appVersion',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingSkeleton(rows: 3);
    if (_error != null) return AppStateView.error(onRetry: _load);
    if (_reports.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: const AppStateView(
          icon: AppIcons.shield,
          title: '暂无待处理举报',
          description: '有人举报内容时，会出现在这里。',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return _ReportRow(report: report, onAction: () => _handle(report));
        },
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.onAction});

  final Map<String, dynamic> report;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final target = report['target'] as Map<String, dynamic>?;
    final targetType = report['target_type']?.toString() ?? '';
    final title = switch (targetType) {
      'entity' =>
        (target?['title']?.toString().trim().isNotEmpty ?? false)
            ? target!['title'].toString()
            : '内容已不存在',
      'comment' => '评论：${target?['content'] ?? '内容已不存在'}',
      _ => '用户：${target?['nickname'] ?? '未知用户'}',
    };
    final excerpt = switch (targetType) {
      'entity' => target?['content']?.toString() ?? '',
      'comment' => target?['content']?.toString() ?? '',
      _ => '用户资料',
    };

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.title.copyWith(color: colors.ink),
                ),
              ),
              IconButton(
                tooltip: '处理举报',
                onPressed: onAction,
                icon: const Icon(AppIcons.more, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          _Line(label: '举报原因', value: report['reason']?.toString() ?? ''),
          if ((report['details']?.toString().trim().isNotEmpty ?? false))
            _Line(label: '补充说明', value: report['details'].toString()),
          if (excerpt.trim().isNotEmpty)
            _Line(label: '内容摘要', value: excerpt.trim()),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(color: colors.muted)),
          const SizedBox(height: AppSpace.xs),
          Text(value, style: AppText.bodySmall.copyWith(color: colors.ink)),
        ],
      ),
    );
  }
}
