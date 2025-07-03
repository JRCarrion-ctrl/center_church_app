// file: lib/features/groups/groups_page.dart
import 'package:flutter/material.dart';
import 'your_groups_section.dart';
import 'joinable_groups_section.dart';
import 'invitations_section.dart';
import 'group_admin_tools_section.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  YourGroupsSection(),
                  SizedBox(height: 24),
                  JoinableGroupsSection(),
                  SizedBox(height: 24),
                  InvitationsSection(),
                  SizedBox(height: 24),
                  GroupAdminToolsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
