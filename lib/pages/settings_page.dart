import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_version.dart';
import '../services/contact_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/activity_form_sheets.dart';
import '../widgets/app/app_icons.dart';
import 'legal_page.dart';

/// 个人主页右上角齿轮进入的设置。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  /// 反馈与申诉用的邮箱，改这里就能全站生效。
  static const String contactEmail = 'hello@skneo.club';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _phone;
  bool _loadingPhone = true;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {    final phone = await ContactService().loadMine();
    if (!mounted) return;
    setState(() {
      _phone = phone;
      _loadingPhone = false;
    });
  }

  Future<void> _editPhone() async {
    final saved = await showPhoneSheet(
      context,
      initial: _phone,
      title: _phone == null ? '填写手机号' : '修改手机号',
    );
    if (saved == null || !mounted) return;
    setState(() => _phone = saved);
  }

  Future<void> _clearPhone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除手机号？'),
        content: const Text('清除后，发起活动时会要求你重新填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ContactService().clearMine();
    if (!mounted) return;
    setState(() => _phone = null);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openLegal(LegalDocument document) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LegalPage(document: document)),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final signedIn = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.huge),
        children: [
          _sectionLabel('账号'),
          if (signedIn) ...[
            _Row(
              label: '手机号',
              value: _loadingPhone
                  ? ''
                  : (_phone == null ? '未填写' : ContactService.mask(_phone!)),
              onTap: _editPhone,
            ),
            if (_phone != null)
              _Row(label: '清除手机号', danger: true, onTap: _clearPhone),
            _note('手机号只在约活动时提供给对方，个人主页不会展示。'),
          ] else
            _note('登录后可以管理手机号等账号信息。'),

          _sectionLabel('关于'),
          _Row(
            label: '版本',
            value: 'v$appVersion',
          ),
          _note(appVersionNote),
          _Row(label: '用户协议', onTap: () => _openLegal(LegalDocument.terms)),
          _Row(label: '隐私政策', onTap: () => _openLegal(LegalDocument.privacy)),

          _sectionLabel('支持'),
          _Row(
            label: '联系我们',
            onTap: () => _showContact(context),
          ),
          _note('举报、申诉、注销账号，都可以发邮件到这里。'),

          if (signedIn) ...[
            const SizedBox(height: AppSpace.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: TextButton(
                onPressed: _signOut,
                child: Text(
                  '退出登录',
                  style: AppText.body.copyWith(color: colors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showContact(BuildContext context) {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('联系我们'),
        content: SelectableText(
          SettingsPage.contactEmail,
          style: AppText.body.copyWith(color: colors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.xxl,
        AppSpace.xl,
        AppSpace.sm,
      ),
      child: Text(
        text,
        style: AppText.caption.copyWith(
          color: colors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _note(String text) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.xs,
        AppSpace.xl,
        AppSpace.sm,
      ),
      child: Text(
        text,
        style: AppText.caption.copyWith(color: colors.muted, height: 1.6),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.value,
    this.onTap,
    this.danger = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppText.body.copyWith(
                color: danger ? colors.danger : colors.ink,
              ),
            ),
            const Spacer(),
            if (hasValue)
              Text(
                value!,
                style: AppText.bodySmall.copyWith(color: colors.muted),
              ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpace.xs),
              Icon(AppIcons.chevron, size: 18, color: colors.muted),
            ],
          ],
        ),
      ),
    );
  }
}
