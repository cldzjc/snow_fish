import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';
import 'app_icons.dart';

/// 加载骨架屏。
class AppLoadingSkeleton extends StatefulWidget {
  const AppLoadingSkeleton({super.key, this.rows = 2});

  final int rows;

  @override
  State<AppLoadingSkeleton> createState() => _AppLoadingSkeletonState();
}

class _AppLoadingSkeletonState extends State<AppLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1).animate(_controller),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.xl,
        ),
        itemCount: widget.rows,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpace.xxxl),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Block(color: colors.soft, width: 44, height: 44, round: true),
                const SizedBox(width: AppSpace.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Block(color: colors.soft, width: 96, height: 12),
                    const SizedBox(height: AppSpace.sm),
                    _Block(color: colors.soft, width: 56, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            _Block(color: colors.soft, width: double.infinity, height: 14),
            const SizedBox(height: AppSpace.sm),
            _Block(color: colors.soft, width: 220, height: 14),
            const SizedBox(height: AppSpace.md),
            _Block(color: colors.soft, width: double.infinity, height: 160),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.color,
    required this.width,
    required this.height,
    this.round = false,
  });

  final Color color;
  final double? width;
  final double height;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(round ? height / 2 : AppRadius.sm),
      ),
    );
  }
}

/// 空数据 / 加载失败 / 未登录 的统一版式。
class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 通用空数据。
  factory AppStateView.empty({Key? key, String title = '还没有内容'}) {
    return AppStateView(
      key: key,
      icon: AppIcons.mountain,
      title: title,
      description: '留一点空白，等下一段雪上的故事。',
    );
  }

  /// 加载失败。
  factory AppStateView.error({Key? key, VoidCallback? onRetry}) {
    return AppStateView(
      key: key,
      icon: AppIcons.alert,
      title: '暂时没有加载出来',
      description: '请检查网络后再试一次。',
      actionLabel: onRetry == null ? null : '重新加载',
      onAction: onRetry,
    );
  }

  /// 未登录。
  factory AppStateView.login({Key? key, required VoidCallback onLogin}) {
    return AppStateView(
      key: key,
      icon: AppIcons.person,
      title: '登录，记录你的雪上日常',
      description: '与雪友分享，也为下一次相约出发。',
      actionLabel: '登录 / 注册',
      onAction: onLogin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 380,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xxl,
                  vertical: AppSpace.xxxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 34, color: colors.muted),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.title.copyWith(color: colors.ink),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: AppSpace.md),
                      Text(
                        description!,
                        textAlign: TextAlign.center,
                        style: AppText.bodySmall.copyWith(color: colors.muted),
                      ),
                    ],
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: AppSpace.xl),
                      AppButton(label: actionLabel!, onPressed: onAction),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
