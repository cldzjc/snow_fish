import 'package:flutter/material.dart';

class MessagePlaceholderPage extends StatelessWidget {
  const MessagePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('还没开发呢，等着吧', style: TextStyle(fontSize: 18))),
    );
  }
}
