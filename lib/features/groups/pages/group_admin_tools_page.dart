// File: lib/features/groups/pages/group_admin_tools_page.dart
import 'package:flutter/material.dart';

class GroupAdminToolsPage extends StatelessWidget {
  final String groupId;

  const GroupAdminToolsPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: const Center(
        child: Text('This is where admin tools will appear.'),
      ),
    );
  }
}
