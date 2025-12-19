import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _generatedCode;

  // 发送验证码
  Future<void> _sendVerificationCode() async {
    if (_emailController.text.isEmpty || _nameController.text.isEmpty) {
      _showError('请先填写用户名和邮箱');
      return;
    }

    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(_emailController.text)) {
      _showError('请输入有效的邮箱地址');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 生成验证码
      _generatedCode = _generateVerificationCode();

      // 模拟发送邮件 - 在实际项目中，这里应该调用后端API
      // 为了演示，我们显示验证码对话框
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('验证码已发送'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('您的验证码是：'),
                const SizedBox(height: 8),
                Text(
                  _generatedCode!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '（学习项目演示用，实际应用中不会显示）',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }

      setState(() {
        _codeSent = true;
      });

      _showSuccess('验证码已发送到您的邮箱');
    } catch (e) {
      _showError('发送验证码失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 完成注册
  Future<void> _completeRegistration() async {
    if (_verificationCodeController.text != _generatedCode) {
      _showError('验证码错误，请重新输入');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('两次输入的密码不一致');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('密码长度至少6位');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'name': _nameController.text.trim()},
      );

      if (mounted) {
        _showSuccess('注册成功！请检查邮箱进行验证');
        // 注册成功后返回登录页
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('注册失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 生成6位随机验证码
  String _generateVerificationCode() {
    return (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
        .toString();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text(
              '创建新账户',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('加入我们的二手交易社区', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // 用户名输入
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // 邮箱输入
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '邮箱地址',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // 密码输入
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码 (至少6位)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            // 确认密码
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: '确认密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // 发送验证码按钮
            if (!_codeSent)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendVerificationCode,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('发送验证码'),
                ),
              )
            else
              Column(
                children: [
                  // 验证码输入
                  TextField(
                    controller: _verificationCodeController,
                    decoration: const InputDecoration(
                      labelText: '请输入6位验证码',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.verified),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 16),

                  // 完成注册按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeRegistration,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('完成注册'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 重新发送验证码
                  TextButton(
                    onPressed: _isLoading ? null : _sendVerificationCode,
                    child: const Text('重新发送验证码'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 返回登录页
              },
              child: const Text('已有账号？去登录'),
            ),
          ],
        ),
      ),
    );
  }
}
