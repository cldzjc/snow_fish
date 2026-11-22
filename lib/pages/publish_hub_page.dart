import 'package:flutter/material.dart';
import 'publish_post_page.dart';

class PublishHubPage extends StatelessWidget {
  final bool defaultActivity;

  const PublishHubPage({super.key, this.defaultActivity = false});

  @override
  Widget build(BuildContext context) {
    if (!defaultActivity) {
      return const PublishPostPage();
    }

    const types = <(String, String, IconData)>[
      ('activity_ski', '约滑', Icons.downhill_skiing),
      ('activity_photo', '约拍', Icons.camera_alt_outlined),
      ('activity_food', '约饭', Icons.restaurant_outlined),
      ('activity_gear', '约装备', Icons.backpack_outlined),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('选择活动类型')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final item = types[index];
          return Card(
            child: ListTile(
              leading: Icon(item.$3),
              title: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PublishPostPage(
                    initialEntityType: item.$1,
                    initialActivityType: item.$1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
