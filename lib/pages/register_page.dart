import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import 'legal_page.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  Timer? _countdownTimer;
  bool _isLoading = false;
  bool _otpSent = false;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.colors.danger : null,
      ),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _toast('请输入有效的邮箱地址', error: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {'role': 'user'},
      );
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startCountdown();
      _toast('验证码已发送，请检查邮箱');
    } on SocketException {
      _toast('网络无法连接，请检查网络设置', error: true);
    } on AuthException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('验证码发送失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _otpController.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      _toast('请输入邮件中的 6 位验证码', error: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (response.session != null) {
        await ProfileSyncService().ensureCurrentProfile();
      }
      if (mounted && response.session != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('注册成功')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('验证码验证失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xxl,
          AppSpace.sm,
          AppSpace.xxl,
          AppSpace.xxxl,
        ),
        children: [
          Text('skneo.', style: AppText.brand.copyWith(color: colors.ink)),
          const SizedBox(height: AppSpace.xxl),
          Text('从这里，加入雪友。', style: AppText.display.copyWith(color: colors.ink)),
          const SizedBox(height: AppSpace.xxxl),
          AppField(
            label: '邮箱',
            requiredMark: true,
            child: AppTextField(
              controller: _emailController,
              hint: '输入邮箱地址',
              keyboardType: TextInputType.emailAddress,
              enabled: !_otpSent,
            ),
          ),
          if (_otpSent) ...[
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '验证码',
              requiredMark: true,
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _otpController,
                      hint: '6 位验证码',
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      maxLength: 6,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  AppButton(
                    label: _secondsRemaining > 0
                        ? '${_secondsRemaining}s'
                        : '重发',
                    variant: AppButtonVariant.outline,
                    dense: true,
                    onPressed: _isLoading || _secondsRemaining > 0
                        ? null
                        : _sendCode,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xxl),
          AppButton(
            label: _otpSent ? '注册' : '发送验证码',
            expand: true,
            loading: _isLoading,
            onPressed: _otpSent ? _verifyCode : _sendCode,
          ),
          const SizedBox(height: AppSpace.md),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            child: Text(
              '已有账号？去登录',
              style: AppText.bodySmall.copyWith(color: colors.muted),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _AgreementLine(),
        ],
      ),
    );
  }
}

/// 注册即表示同意条款；两个名称可直接点开阅读。
class _AgreementLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = AppText.caption.copyWith(color: colors.muted, height: 1.6);
    final linkStyle = style.copyWith(
      color: colors.ink,
      decoration: TextDecoration.underline,
    );

    void open(LegalDocument document) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalPage(document: document)),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('注册即表示同意', style: style),
        GestureDetector(
          onTap: () => open(LegalDocument.terms),
          child: Text('《用户协议》', style: linkStyle),
        ),
        Text('和', style: style),
        GestureDetector(
          onTap: () => open(LegalDocument.privacy),
          child: Text('《隐私政策》', style: linkStyle),
        ),
      ],
    );
  }
}
