import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/geo.dart';
import '../services/profile_sync_service.dart';
import '../services/turnstile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();
  final _turnstileService = TurnstileService();

  Timer? _countdownTimer;
  bool _isLoading = false;
  bool _otpSent = false;
  int _secondsRemaining = 0;

  String _residentRegion = '';
  String _residentResort = GeoData.noFixedResort;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _nameController.dispose();
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
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty) {
      _toast('请输入用户名', error: true);
      return;
    }
    if (_residentRegion.isEmpty) {
      _toast('请选择常驻地区', error: true);
      return;
    }
    if (!_isValidEmail(email)) {
      _toast('请输入有效的邮箱地址', error: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_turnstileService.isSupported) {
        final token = await _turnstileService.getToken();
        if (token == null ||
            !await _turnstileService.verifyWithSupabase(token)) {
          _toast('人机验证未完成，请重试', error: true);
          return;
        }
      }
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {
          'display_name': name,
          'name': name,
          'role': 'user',
          'resident_region': _residentRegion,
          'resident_resort': _residentResort,
        },
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
        await ProfileSyncService().ensureCurrentProfile(
          registrationName: _nameController.text,
          residentRegion: _residentRegion,
          residentResort: _residentResort,
        );
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
          const SizedBox(height: AppSpace.sm),
          Text(
            '常驻地区会作为你的身份标签，出现在你的内容旁。',
            style: AppText.bodySmall.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpace.xxxl),
          if (!_otpSent) ...[
            AppField(
              label: '用户名',
              requiredMark: true,
              child: AppTextField(controller: _nameController, hint: '你的雪友昵称'),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '常驻地区',
              requiredMark: true,
              child: AppDropdown<String>(
                options: [
                  for (final province in GeoData.provinces)
                    AppOption<String>(province, province),
                ],
                value: _residentRegion.isEmpty ? null : _residentRegion,
                hint: '请选择常驻地区',
                onChanged: (value) =>
                    setState(() => _residentRegion = value ?? ''),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '常驻雪场',
              note: '可先选「${GeoData.noFixedResort}」',
              child: AppDropdown<String>(
                options: [
                  for (final resort in GeoData.resorts)
                    AppOption<String>(resort, resort),
                ],
                value: _residentResort,
                onChanged: (value) => setState(
                  () => _residentResort = value ?? GeoData.noFixedResort,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
          ],
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
        ],
      ),
    );
  }
}
