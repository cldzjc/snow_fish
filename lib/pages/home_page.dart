import 'package:flutter/material.dart';
import 'posts_list_widget.dart';
import 'publish_post_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '雪鱼社区',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: const PostsListWidget(),
      floatingActionButton: FloatingActionButton(
        tooltip: '发布动态',
        onPressed: () async {
          final published = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const PublishPostPage()),
          );
          if (published == true && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('动态发布成功')));
          }
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}
