import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/turnstile_service.dart';
import '../services/profile_sync_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();
  Timer? _countdownTimer;
  bool _isLoading = false;
  bool _otpSent = false;
  int _secondsRemaining = 0;
  String? _residentRegion;
  String _residentResort = '暂无固定雪场';
  final _turnstileService = TurnstileService();

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('请输入用户名');
      return;
    }
    if (_residentRegion == null || _residentRegion!.isEmpty) {
      _showError('请选择常驻地区');
      return;
    }
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
    final email = _emailController.text.trim();
    final code = _otpController.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      _showError('请输入邮件中的6位数字验证码');
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
        _showSuccess('注册成功');
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
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text(
              '创建新账户',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '加入 Snow Fish 滑雪内容社区',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (!_otpSent) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _residentRegion,
                decoration: const InputDecoration(
                  labelText: '常驻地区（必选）',
                  border: OutlineInputBorder(),
                ),
                items:
                    const [
                          '北京',
                          '河北',
                          '吉林',
                          '辽宁',
                          '黑龙江',
                          '内蒙古',
                          '山东',
                          '新疆',
                          '甘肃',
                          '四川',
                          '云南',
                          '陕西',
                          '山西',
                          '其他',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _residentRegion = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _residentResort,
                decoration: const InputDecoration(
                  labelText: '常驻雪场',
                  border: OutlineInputBorder(),
                ),
                items:
                    const [
                          '暂无固定雪场',
                          '崇礼·富龙',
                          '崇礼·万龙',
                          '崇礼·云顶',
                          '崇礼·太舞',
                          '河北·崇礼',
                          '新疆·阿勒泰',
                          '吉林·北大湖',
                          '辽宁·抚顺雷锋',
                          '北京·莲石湖',
                          '甘肃·平堡',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    setState(() => _residentResort = value ?? '暂无固定雪场'),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _emailController,
              enabled: !_otpSent,
              decoration: const InputDecoration(
                labelText: '邮箱地址',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            if (_otpSent) ...[
              const SizedBox(height: 24),
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
              const SizedBox(height: 8),
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
            const SizedBox(height: 16),
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
                    : Text(_otpSent ? '验证并注册' : '发送验证码'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('已有账号？去登录'),
            ),
          ],
        ),
      ),
    );
  }
}
