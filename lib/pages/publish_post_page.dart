import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../post_service.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'edit_profile_page.dart';

class PublishPostPage extends StatefulWidget {
  const PublishPostPage({super.key});

  @override
  State<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends State<PublishPostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<String> _presetImages = [
    'https://picsum.photos/600/300?random=11',
    'https://picsum.photos/600/300?random=12',
    'https://picsum.photos/600/300?random=13',
  ];
  String? _selectedMedia;
  bool _isLoading = false;

  bool _isLoggedIn() {
    return Supabase.instance.client.auth.currentUser != null;
  }

  Future<void> _publish() async {
    if (!_isLoggedIn()) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!_isLoggedIn()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要登录才能发布')));
        return;
      }
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写标题')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final media = _selectedMedia != null ? [_selectedMedia!] : <String>[];
      await PostService().createPost(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        mediaUrls: media,
      );
      // 发布成功，返回并通知刷新
      Navigator.pop(context, true);
      // Add navigation to ProfilePage
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not_logged_in')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('你还未登录')));
      } else if (msg.contains('network:')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('网络错误，发布失败')));
      } else if (msg.contains('permission:')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('权限错误，无法发布')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发布失败: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布帖子'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '正文',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text('选择图片（可选）'),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presetImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = _presetImages[i];
                  final selected = _selectedMedia == url;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMedia = url),
                    child: Stack(
                      children: [
                        Image.network(
                          url,
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                        if (selected)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _publish,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isLoading ? '发布中...' : '确认发布'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
