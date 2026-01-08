import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nicknameController;
  late TextEditingController _ageController;
  late TextEditingController _bioController;

  String _selectedGender = '其他'; // 默认值
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata ?? {};
      _nicknameController = TextEditingController(
        text: metadata['nickname'] as String? ?? '',
      );
      _ageController = TextEditingController(
        text: metadata['age'] != null ? metadata['age'].toString() : '',
      );
      _selectedGender = (metadata['gender'] as String?) ?? '其他';
      _bioController = TextEditingController(
        text: metadata['bio'] as String? ?? '',
      );
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nicknameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称不能为空'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final age = _ageController.text.isEmpty
          ? null
          : int.tryParse(_ageController.text);
      final newMetadata = {
        // 保存两套字段以兼容现有代码：'name' 作为主要用户名，'nickname' 作为显示昵称
        'name': _nicknameController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        if (age != null) 'age': age,
        'gender': _selectedGender,
        'bio': _bioController.text.trim(),
      };

      // 更新用户 metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: newMetadata),
      );

      // 主动获取最新用户信息以确保本地状态同步
      try {
        await Supabase.instance.client.auth.getUser();
      } catch (_) {
        // 忽略刷新错误（兼容性）
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('个人资料已保存')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑个人资料')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 昵称
            Text('昵称', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                hintText: '输入昵称',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 年龄
            Text('年龄', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '输入年龄',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 性别
            Text('性别', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedGender,
                isExpanded: true,
                underline: Container(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items:
                    const [
                          DropdownMenuItem(value: '男', child: Text('男')),
                          DropdownMenuItem(value: '女', child: Text('女')),
                          DropdownMenuItem(value: '其他', child: Text('其他')),
                        ]
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.value,
                            child: Padding(
                              padding: EdgeInsets.zero,
                              child: Text(item.value ?? ''),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // 个人介绍
            Text('个人介绍', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '分享你的个人介绍',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
