import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/turnstile_service.dart';
import '../services/profile_sync_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  Timer? _countdownTimer;
  bool _isLoading = false;
  bool _otpSent = false;
  int _secondsRemaining = 0;
  final _turnstileService = TurnstileService();

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showError('请输入有效的邮箱地址');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_turnstileService.isSupported) {
        final turnstileToken = await _turnstileService.getToken();
        if (turnstileToken == null ||
            !await _turnstileService.verifyWithSupabase(turnstileToken)) {
          _showError('人机验证未完成，请重试');
          return;
        }
      }
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startCountdown();
      _showSuccess('验证码已发送，请检查邮箱');
    } on SocketException {
      _showError('网络无法连接，请检查网络设置');
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('验证码发送失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      _showError('请输入邮件中的6位数字验证码');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: code,
        type: OtpType.email,
      );
      if (response.session != null) {
        await ProfileSyncService().ensureCurrentProfile();
      }
      if (mounted && response.session != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('验证码验证失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              enabled: !_otpSent,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            if (_otpSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                autofocus: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '6位邮箱验证码',
                  hintText: '请输入邮件中的验证码',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.verified_user),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading || _secondsRemaining > 0
                      ? null
                      : _sendCode,
                  child: Text(
                    _secondsRemaining > 0
                        ? '${_secondsRemaining}秒后可重新发送'
                        : '重新发送验证码',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_otpSent ? _verifyCode : _sendCode),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_otpSent ? '验证并登录' : '发送验证码'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text('没有账号？去注册'),
            ),
          ],
        ),
      ),
    );
  }
}
