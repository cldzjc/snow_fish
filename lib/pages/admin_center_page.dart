import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_version.dart';
import '../services/moderation_service.dart';
import '../services/shutdown_service.dart';
import '../supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/app_sheet.dart';
import '../widgets/app/app_state_views.dart';
import '../widgets/app/app_tabs.dart';
import '../utils/error_text.dart';

class AdminCenterPage extends StatefulWidget {
  const AdminCenterPage({super.key});

  @override
  State<AdminCenterPage> createState() => _AdminCenterPageState();
}

class _AdminCenterPageState extends State<AdminCenterPage> {
  final ModerationService _service = ModerationService();
  final TextEditingController _shutdownMessage = TextEditingController(
    text: ShutdownService.defaultMessage,
  );

  bool _loading = true;
  String? _error;
  int _tab = 0;
  final List<Map<String, dynamic>> _reports = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _suspended = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shutdownMessage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _service.loadOpenReports();
      final suspended = await _service.loadSuspendedUsers();
      if (!mounted) return;
      setState(() {
        _reports
          ..clear()
          ..addAll(reports);
        _suspended
          ..clear()
          ..addAll(suspended);
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
    final targetType = report['target_type']?.toString() ?? '';
    final target = report['target'] as Map<String, dynamic>?;
    final targetId = report['target_id'] as String?;
    final authorId = targetType == 'user'
        ? targetId
        : (target?['user_id'] as String?);
    final authorName = (target?['nickname'] as String?)?.trim();
    final authorLabel = targetType == 'user'
        ? (authorName?.isNotEmpty ?? false ? authorName! : '该用户')
        : (authorName?.isNotEmpty ?? false ? authorName! : '内容作者');

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认处置？'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _impactDescription(targetType, authorLabel),
                style: AppText.bodySmall.copyWith(color: context.colors.ink),
              ),
              const SizedBox(height: AppSpace.lg),
              AppTextField(
                controller: noteController,
                hint: '处理依据（会通知被处理的人）',
                maxLength: 200,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认处置'),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      if (authorId != null && authorId.isNotEmpty) {
        await _service.suspendUser(
          userId: authorId,
          reason: note.isEmpty ? '举报核实成立' : note,
        );
      }

      await _service.resolveReport(
        reportId: report['id'] as String,
        status: 'resolved',
        note: note.isEmpty ? '举报核实成立' : note,
        targetType: targetType,
        targetId: targetId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除内容并封禁账号')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '处置失败'))),
      );
    }
  }

  /// 防呆：把「会动哪些数据」写清楚。
  String _impactDescription(String targetType, String authorLabel) {
    final action = switch (targetType) {
      'entity' => '删除这条帖子（含 OSS 图片，不可恢复）',
      'comment' => '删除这条评论（不可恢复）',
      _ => '关闭该用户的账号权限',
    };
    return '将要执行：\n'
        '· $action\n'
        '· 封禁「$authorLabel」：不能发帖、评论、点赞、收藏、报名活动\n'
        '· 隐藏该作者全部已发布内容（申诉通过后可一键恢复）\n'
        '· 关闭本条举报并通知举报人\n\n'
        '涉及表：entities、comments、interactions、user_profiles、reports、'
        'moderation_actions、notifications。\n不删除该用户的账号本身。';
  }

  /// 置顶 / 取消置顶（只对帖子生效，和「有错 / 没错」是两回事）。
  Future<void> _togglePin(Map<String, dynamic> report) async {
    final entityId = report['target_id'] as String?;
    final target = report['target'] as Map<String, dynamic>?;
    if (entityId == null) return;
    final pinned = target?['pinned_at'] != null;
    try {
      await _service.setEntityPinned(
        entityId: entityId,
        pinned: !pinned,
        until: pinned ? null : DateTime.now().add(const Duration(days: 7)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pinned ? '已取消置顶' : '已置顶 7 天')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '置顶操作失败'))),
      );
    }
  }

  Future<void> _dismiss(Map<String, dynamic> report) async {
    setState(() => _loading = true);
    try {
      await _service.resolveReport(
        reportId: report['id'] as String,
        status: 'dismissed',
        note: '经核查无需处理',
        targetType: report['target_type']?.toString(),
        targetId: report['target_id'] as String?,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已忽略，不做处理')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '操作失败'))),
      );
    }
  }

  /// 紧急操作：全站关停。
  ///
  /// 会把「动哪张表、影响谁」写清楚，确认框再复述一遍，
  /// 避免一个人管理的时候手滑。
  Future<void> _showEmergency() async {
    final state = await ShutdownService.load();
    if (!mounted) return;
    final closedNow = state?.closed ?? false;
    final savedText = (state?.text.isNotEmpty ?? false)
        ? state!.text
        : ShutdownService.defaultMessage;
    _shutdownMessage.text = savedText;

    final shouldApply = await showAppSheet<bool>(
      context,
      title: '紧急操作',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '当前状态：${closedNow ? '已关停' : '正常运行'}',
              style: AppText.body.copyWith(color: sheetContext.colors.ink),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              '关停后会发生什么：\n'
              '· 写入 public.app_settings（closed = true），只影响这一个开关，不删除任何帖子、评论、媒体。\n'
              '· 所有人（包括你自己）的页面会变成白屏，只剩下面这行字，首页、圈子、发布全部进不去。\n'
              '· 客户端每 30 秒确认一次，最长 30 秒内全部生效；刷新页面会立刻生效。\n'
              '· 你自己可以在白屏上点「解除关停」恢复，不需要进数据库。',
              style: AppText.bodySmall.copyWith(
                color: sheetContext.colors.muted,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '白屏上显示的提示',
              note: '留空则用默认那一句',
              child: AppTextField(
                controller: _shutdownMessage,
                hint: ShutdownService.defaultMessage,
                maxLength: 60,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            AppButton(
              label: closedNow ? '解除关停' : '关停全站',
              variant: closedNow
                  ? AppButtonVariant.solid
                  : AppButtonVariant.outline,
              expand: true,
              onPressed: () => Navigator.pop(sheetContext, !closedNow),
            ),
          ],
        ),
      ),
    );

    if (shouldApply == null || !mounted) return;

    final turningOff = shouldApply;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(turningOff ? '确认关停全站？' : '确认解除关停？'),
        content: Text(
          turningOff
              ? '所有访客（包括你）会立刻看到白屏，只有你自己能在白屏上解除。\n\n'
                    '不会删除任何数据，解除后原样恢复。'
              : '恢复后所有人可以正常访问。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(turningOff ? '确认关停' : '确认解除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final userId = SupabaseClientManager.instance.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await ShutdownService.setClosed(
        closed: turningOff,
        text: _shutdownMessage.text,
        userId: userId,
      );
      if (!mounted) return;
      if (!turningOff) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已解除关停')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '操作失败'))),
      );
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
            onPressed: _showEmergency,
            child: Text(
              '紧急操作',
              style: AppText.caption.copyWith(color: colors.danger),
            ),
          ),
          TextButton(
            onPressed: _showBuildInfo,
            child: Text(
              'v$appVersion',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          AppTabs(
            tabs: <String>[
              '待处理举报 ${_reports.length}',
              '已封禁 ${_suspended.length}',
            ],
            index: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
          Expanded(child: _tab == 0 ? _buildBody() : _buildSuspendedBody()),
        ],
      ),
    );
  }

  /// 解封：申诉通过后把账号与内容一起恢复。
  Future<void> _restore(Map<String, dynamic> user) async {
    final userId = user['id'] as String?;
    if (userId == null) return;
    final nickname = (user['nickname'] as String?)?.trim();
    final label = (nickname == null || nickname.isEmpty) ? '该用户' : nickname;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('解封「$label」？'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将要执行：\n'
                '· 账号恢复为正常，可以发帖、评论、点赞、收藏、报名\n'
                '· 把「因封号而隐藏」的内容全部恢复可见\n'
                '· 不会恢复已经被删除的内容\n\n'
                '涉及表：user_profiles、entities、comments、moderation_actions、notifications。',
                style: AppText.bodySmall.copyWith(color: context.colors.ink),
              ),
              const SizedBox(height: AppSpace.lg),
              AppTextField(
                controller: noteController,
                hint: '解封说明（选填）',
                maxLength: 200,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认解封'),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final restored = await _service.restoreUser(
        userId: userId,
        note: note.isEmpty ? '申诉通过，解除限制' : note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已解封，恢复 $restored 条内容')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: '解封失败'))),
      );
    }
  }

  Widget _buildSuspendedBody() {
    final colors = context.colors;
    if (_loading) return const AppLoadingSkeleton(rows: 2);
    if (_suspended.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: const AppStateView(
          icon: AppIcons.check,
          title: '没有被封禁的用户',
          description: '封禁用户后，可以在这里解封并恢复内容。',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _suspended.length,
        itemBuilder: (context, index) {
          final user = _suspended[index];
          final nickname = (user['nickname'] as String?)?.trim();
          final reason = (user['account_status_reason'] as String?)?.trim();
          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (nickname == null || nickname.isEmpty) ? '未命名用户' : nickname,
                  style: AppText.title.copyWith(color: colors.ink),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '封禁原因：${(reason == null || reason.isEmpty) ? '未填写' : reason}',
                  style: AppText.bodySmall.copyWith(color: colors.muted),
                ),
                const SizedBox(height: AppSpace.md),
                AppButton(
                  label: '解封并恢复内容',
                  variant: AppButtonVariant.outline,
                  dense: true,
                  expand: true,
                  onPressed: () => _restore(user),
                ),
              ],
            ),
          );
        },
      ),
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

    final colors = context.colors;
    final groups = <String, List<Map<String, dynamic>>>{
      'user': <Map<String, dynamic>>[],
      'entity': <Map<String, dynamic>>[],
      'comment': <Map<String, dynamic>>[],
    };
    for (final report in _reports) {
      final type = report['target_type']?.toString() ?? '';
      (groups[type] ?? groups['entity']!).add(report);
    }

    const titles = <String, String>{
      'user': '用户',
      'entity': '帖子',
      'comment': '评论',
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (final entry in groups.entries)
            if (entry.value.isNotEmpty) ...[
              Container(
                width: double.infinity,
                color: colors.soft,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.sm,
                  AppSpace.xl,
                  AppSpace.sm,
                ),
                child: Text(
                  '${titles[entry.key]} · ${entry.value.length} 条待处理',
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ),
              for (final report in entry.value)
                _ReportRow(
                  report: report,
                  onPunish: () => _handle(report),
                  onDismiss: () => _dismiss(report),
                  onTogglePin: entry.key == 'entity'
                      ? () => _togglePin(report)
                      : null,
                ),
            ],
          const SizedBox(height: AppSpace.xxxl),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.onPunish,
    required this.onDismiss,
    this.onTogglePin,
  });

  final Map<String, dynamic> report;
  final VoidCallback onPunish;
  final VoidCallback onDismiss;

  /// 仅帖子举报可用：置顶 / 取消置顶。
  final VoidCallback? onTogglePin;

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
    final authorId = targetType == 'user'
        ? report['target_id']?.toString()
        : target?['user_id']?.toString();
    final authorName = (target?['nickname'] as String?)?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.title.copyWith(color: colors.ink)),
          if (targetType != 'user' &&
              authorId != null &&
              authorId.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              authorName.isEmpty ? '作者：未知' : '作者：$authorName',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          _Line(label: '举报原因', value: report['reason']?.toString() ?? ''),
          if ((report['details']?.toString().trim().isNotEmpty ?? false))
            _Line(label: '补充说明', value: report['details'].toString()),
          if (excerpt.trim().isNotEmpty)
            _Line(
              label: '内容摘要',
              value: excerpt.trim(),
              maxLines: targetType == 'user' ? 2 : 4,
            ),
          const SizedBox(height: AppSpace.xs),
          if (onTogglePin != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onTogglePin,
                child: Text(
                  target?['pinned_at'] != null ? '取消置顶' : '置顶 7 天',
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '有错，封他删他',
                  dense: true,
                  expand: true,
                  onPressed: onPunish,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: AppButton(
                  label: '没错，不必理会',
                  variant: AppButtonVariant.outline,
                  dense: true,
                  expand: true,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.maxLines = 3});

  final String label;
  final String value;
  final int maxLines;

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
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySmall.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}
