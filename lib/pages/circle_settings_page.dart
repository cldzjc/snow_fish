import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import '../services/circle_repository.dart';
import '../services/my_profile_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/geo_picker_sheet.dart';
import 'circle_feed_widget.dart';

/// 圈子设置：切换浏览范围（城市圈 / 雪场圈）以及入圈、换圈。
///
/// 换圈由数据库的 30 天锁定触发器把关，这里只负责把状态说清楚。
class CircleSettingsPage extends StatefulWidget {
  const CircleSettingsPage({super.key});

  @override
  State<CircleSettingsPage> createState() => _CircleSettingsPageState();
}

class _CircleSettingsPageState extends State<CircleSettingsPage> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    MyProfileStore.changedTick.addListener(_onChanged);
  }

  @override
  void dispose() {
    MyProfileStore.changedTick.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAndJoin({required bool isChange}) async {
    if (_saving) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      _toast('请先登录');
      return;
    }
    final membership = MyProfileStore.circle;
    final selection = await showGeoPicker(
      context,
      title: isChange ? '换一个圈' : '选择你的圈',
      initialRegion: membership?.region,
      initialResort: membership?.resortName,
    );
    if (selection == null || !mounted) return;

    final circle = CircleRepository.instance.forSelection(
      selection.region,
      selection.resort,
    );
    if (circle == null) {
      _toast('请选择到区县，才有对应的圈子');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${isChange ? '换到' : '加入'}${circle.label}？'),
        content: Text(
          isChange
              ? '换圈后 30 天内不能再改，确定要换到${circle.label}吗？'
              : '入圈后 30 天内不能换圈。之后可以在城市圈与雪场圈之间自由切换浏览范围。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isChange ? '换圈' : '入圈'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await MyProfileStore.joinCircle(
        region: selection.region,
        resort: selection.resort,
      );
      if (!mounted) return;
      activeCircleForPublish.value = MyProfileStore.circle?.district;
      _toast(isChange ? '已换到${circle.label}' : '已加入${circle.label}');
    } catch (error) {
      if (!mounted) return;
      _toast(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 数据库抛出的锁定期错误直接展示给用户，别包一层看不懂的 PostgrestException。
  String _friendlyError(Object error) {
    final text = error.toString();
    final marker = RegExp(r'换圈要等到[^"]*').stringMatch(text);
    if (marker != null) return marker;
    return '操作失败：$text';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final membership = MyProfileStore.circle;
    final now = DateTime.now();
    final locked = membership?.isLockedAt(now) ?? false;
    final remaining = membership?.remainingLockDaysAt(now) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('圈子设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          AppSpace.xxxl,
        ),
        children: [
          Text('我的圈子', style: AppText.title.copyWith(color: colors.ink)),
          const SizedBox(height: AppSpace.md),
          if (membership == null)
            Text(
              '还没有入圈。选一个城市或雪场，只看同圈雪友的分享。',
              style: AppText.body.copyWith(color: colors.ink),
            )
          else
            _buildMembershipCard(context, membership, locked, remaining),
          const SizedBox(height: AppSpace.xxl),
          if (membership != null) ...[
            Text('浏览范围', style: AppText.title.copyWith(color: colors.ink)),
            const SizedBox(height: AppSpace.xs),
            Text(
              '回城市圈能看到旗下所有雪场的帖子，去雪场圈只看本雪场。切换浏览范围不影响发帖归属。',
              style: AppText.bodySmall.copyWith(color: colors.muted),
            ),
            const SizedBox(height: AppSpace.md),
            _buildScopeSwitch(membership),
            const SizedBox(height: AppSpace.xxl),
            Text('换圈', style: AppText.title.copyWith(color: colors.ink)),
            const SizedBox(height: AppSpace.xs),
            Text(
              locked ? '锁定期内不能换圈，还需要 $remaining 天。' : '已经可以换圈了，换圈后重新计算 30 天。',
              style: AppText.bodySmall.copyWith(color: colors.muted),
            ),
            const SizedBox(height: AppSpace.md),
            AppButton(
              label: locked ? '还需 $remaining 天才能换圈' : '换一个圈',
              variant: locked
                  ? AppButtonVariant.outline
                  : AppButtonVariant.solid,
              onPressed: locked || _saving
                  ? null
                  : () => _pickAndJoin(isChange: true),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              '没有退圈入口：想离开当前圈，等锁定期结束后直接换到别的圈即可。',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ] else
            AppButton(
              label: '入圈',
              onPressed: _saving ? null : () => _pickAndJoin(isChange: false),
            ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard(
    BuildContext context,
    CircleMembership membership,
    bool locked,
    int remaining,
  ) {
    final colors = context.colors;
    final resort = membership.resort;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  membership.district.label,
                  style: AppText.display.copyWith(color: colors.ink),
                ),
              ),
              if (resort != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.line),
                  ),
                  child: Text(
                    resort.label,
                    style: AppText.caption.copyWith(color: colors.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            openedAtLabel(membership),
            style: AppText.bodySmall.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            locked ? '换圈锁定中，还需 $remaining 天' : '锁定期已结束，可以换圈',
            style: AppText.bodySmall.copyWith(
              color: locked ? colors.danger : colors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeSwitch(CircleMembership membership) {
    final colors = context.colors;
    final resort = membership.resort;
    final current = activeCircleForPublish.value ?? membership.district;

    if (resort == null) {
      return Text(
        '你选的是城市圈，暂时没有更细的雪场圈可选。',
        style: AppText.bodySmall.copyWith(color: colors.muted),
      );
    }

    return Column(
      children: [
        _ScopeRow(
          title: membership.district.label,
          hint: '回城市圈，看旗下所有雪场',
          active: current.id == membership.district.id,
          onTap: () {
            activeCircleForPublish.value = membership.district;
            setState(() {});
          },
        ),
        _ScopeRow(
          title: resort.label,
          hint: '去雪场圈，只看${resort.name}',
          active: current.id == resort.id,
          onTap: () {
            activeCircleForPublish.value = resort;
            setState(() {});
          },
        ),
      ],
    );
  }
}

/// 入圈时间文案。
String openedAtLabel(CircleMembership membership) {
  final joined = membership.joinedAt;
  if (joined == null) return '入圈时间未知';
  final until = membership.lockedUntil;
  final head = '入圈于 ${joined.year}-${_two(joined.month)}-${_two(joined.day)}';
  if (until == null) return head;
  final tail = '${until.year}-${_two(until.month)}-${_two(until.day)}';
  return '$head · 锁定至 $tail';
}

String _two(int value) => value.toString().padLeft(2, '0');

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.title,
    required this.hint,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: active ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(
                        color: colors.ink,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: AppText.caption.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (active)
                Icon(AppIcons.check, size: 18, color: colors.ink)
              else
                Icon(AppIcons.chevron, size: 18, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 圈子 Tab 顶部那一行：只有当前圈子名，点开进设置。
class CircleHeaderBar extends StatelessWidget {
  const CircleHeaderBar({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final membership = MyProfileStore.circle;
    final current = activeCircleForPublish.value ?? membership?.district;
    final label = current?.label ?? '还没入圈';

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: '圈子设置，当前 $label',
        child: InkWell(
          onTap: onOpenSettings,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.title.copyWith(color: colors.ink)),
                const SizedBox(width: 2),
                Icon(AppIcons.chevron, size: 16, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
