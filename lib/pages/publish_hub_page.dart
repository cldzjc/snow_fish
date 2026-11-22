import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_icons.dart';
import 'publish_post_page.dart';

/// 发布入口。
///
/// 规则（与产品约定一致）：
/// - 在 sk社区点发布，直接进普通帖表单；
/// - 在约约约点发布，先选活动类型，再进对应表单。
class PublishHubPage extends StatelessWidget {
  const PublishHubPage({super.key, this.defaultActivity = false});

  final bool defaultActivity;

  @override
  Widget build(BuildContext context) {
    if (!defaultActivity) {
      return const PublishPostPage();
    }
    return const _ActivityTypePicker();
  }
}

class _ActivityTypePicker extends StatelessWidget {
  const _ActivityTypePicker();

  static const List<_ActivityKind> _kinds = <_ActivityKind>[
    _ActivityKind(
      entityType: 'activity_ski',
      label: '约滑',
      description: '一起滑，下一趟有人作伴',
      icon: AppIcons.ski,
    ),
    _ActivityKind(
      entityType: 'activity_photo',
      label: '约拍',
      description: '记录彼此的雪上瞬间',
      icon: AppIcons.camera,
    ),
    _ActivityKind(
      entityType: 'activity_food',
      label: '约饭',
      description: '收板之后，吃顿热的',
      icon: AppIcons.food,
    ),
    _ActivityKind(
      entityType: 'activity_gear',
      label: '约装备',
      description: '聊聊这个雪季的装备',
      icon: AppIcons.gear,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('发起活动')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          AppSpace.xxl,
        ),
        children: [
          Text('这一次，约什么？', style: AppText.display.copyWith(color: colors.ink)),
          const SizedBox(height: AppSpace.sm),
          Text(
            '选一种方式，和雪友相聚。',
            style: AppText.bodySmall.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpace.xxl),
          for (final kind in _kinds)
            _KindRow(
              kind: kind,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PublishPostPage(initialEntityType: kind.entityType),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityKind {
  const _ActivityKind({
    required this.entityType,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String entityType;
  final String label;
  final String description;
  final IconData icon;
}

class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.onTap});

  final _ActivityKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: kind.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: [
              Icon(kind.icon, size: 22, color: colors.ink),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: AppText.title.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      kind.description,
                      style: AppText.bodySmall.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevron, size: 20, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
