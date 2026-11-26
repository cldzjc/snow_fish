import 'package:flutter/material.dart';

import '../../services/shutdown_service.dart';
import '../../supabase_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

/// 全站关停时的白屏提示。
///
/// 只剩一行小字。管理员登录状态下会多一个解除入口，
/// 避免唯一的站长得靠进数据库才能把自己放出来。
class ShutdownScreen extends StatefulWidget {
  const ShutdownScreen({super.key, required this.message});

  final String message;

  @override
  State<ShutdownScreen> createState() => _ShutdownScreenState();
}

class _ShutdownScreenState extends State<ShutdownScreen> {
  bool _isAdmin = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final user = SupabaseClientManager.instance.auth.currentUser;
      if (user == null) return;
      final row = await SupabaseClientManager.instance
          .from('user_profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _isAdmin = row?['role'] == 'admin');
    } catch (_) {
      // 读不到就当普通访客。
    }
  }

  Future<void> _reopen() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final user = SupabaseClientManager.instance.auth.currentUser;
      if (user == null) throw StateError('请先登录');
      await ShutdownService.setClosed(
        closed: false,
        text: widget.message,
        userId: user.id,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('解除失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                  color: colors.muted,
                  letterSpacing: 0.4,
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(height: AppSpace.xxl),
                AppButton(
                  label: '解除关停',
                  variant: AppButtonVariant.outline,
                  dense: true,
                  loading: _working,
                  onPressed: _working ? null : _reopen,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
