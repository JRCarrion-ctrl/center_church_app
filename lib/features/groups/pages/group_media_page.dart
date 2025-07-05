// File: lib/features/groups/pages/group_media_page.dart
import 'package:flutter/material.dart';

class GroupMediaPage extends StatelessWidget {
  final String groupId;

  const GroupMediaPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Media')),
      body: const Center(
        child: Text('This is where shared media will appear.'),
      ),
    );
  }
}
