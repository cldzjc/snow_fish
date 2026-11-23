import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/base_entity.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_icons.dart';

/// 帖子分享：统一生成「标题 + 分享链接」两行文本。
///
/// 链接直接用 entity id，永久有效：
///   https://skneo.club/p/<entity_id>
class ShareService {
  const ShareService._();

  /// 站点根地址（分享链接用，不带结尾斜杠）。
  static const String siteOrigin = 'https://skneo.club';

  /// 帖子永久链接。
  static String postUrl(String entityId) => '$siteOrigin/p/$entityId';

  /// 分享文案：标题一行，链接一行。
  static String postText(BaseEntity entity) {
    final title = entity.title.trim();
    final url = postUrl(entity.id);
    return title.isEmpty ? url : '$title\n$url';
  }

  /// 优先调起系统分享面板；不可用时退回到「可复制文案」面板。
  ///
  /// 微信内置浏览器既不支持 Web Share API，剪贴板权限也常被限制，
  /// 所以兜底面板里放的是可长按选中的文本。
  static Future<void> shareEntity(
    BuildContext context,
    BaseEntity entity, {
    Rect? origin,
  }) async {
    final text = postText(entity);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: entity.title,
          sharePositionOrigin: origin,
        ),
      );
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // 继续走兜底面板。
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareCopySheet(text: text),
    );
  }
}

class _ShareCopySheet extends StatefulWidget {
  const _ShareCopySheet({required this.text});

  final String text;

  @override
  State<_ShareCopySheet> createState() => _ShareCopySheetState();
}

class _ShareCopySheetState extends State<_ShareCopySheet> {
  bool _copied = false;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
      if (mounted) setState(() => _copied = true);
    } catch (_) {
      // 复制失败时依赖长按选中文字。
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '分享到微信 / 雪友',
                style: AppText.title.copyWith(color: colors.ink),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                '复制下面的两行文字，粘贴到群聊即可。',
                style: AppText.bodySmall.copyWith(color: colors.muted),
              ),
              const SizedBox(height: AppSpace.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: colors.soft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: SelectableText(
                  widget.text,
                  style: AppText.body.copyWith(color: colors.ink),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _copy,
                      child: Text(_copied ? '已复制' : '复制文案'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Icon(AppIcons.info, size: 14, color: colors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '按钮没反应时，长按上面的文字也可以选中复制。',
                      style: AppText.caption.copyWith(color: colors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
