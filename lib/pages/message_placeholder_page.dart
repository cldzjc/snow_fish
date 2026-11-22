import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_icons.dart';

/// 私信占位页。功能未开发，不展示任何虚假数据。
class MessagePlaceholderPage extends StatelessWidget {
  const MessagePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  '私信',
                  style: AppText.pageTitle.copyWith(color: colors.ink),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.mail, size: 34, color: colors.muted),
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        '还没开发呢，等着吧',
                        textAlign: TextAlign.center,
                        style: AppText.title.copyWith(color: colors.ink),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        '这里以后会放雪友之间的对话。',
                        textAlign: TextAlign.center,
                        style: AppText.bodySmall.copyWith(color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
