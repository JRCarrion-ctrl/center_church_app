// File: lib/features/groups/widgets/admin_tools_widget.dart
import 'package:flutter/material.dart';
import '../../../shared/widgets/primary_button.dart';
import '../models/group.dart';
import '../pages/edit_group_info_page.dart';
import 'package:go_router/go_router.dart';
import 'group_deletion_request_modal.dart';

class AdminToolsWidget extends StatelessWidget {
  final Group group;

  const AdminToolsWidget({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Admin Tools for ${group.name}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),

        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Group Info'),
          subtitle: Text(group.description ?? 'No description'),
          onTap: () async {
            final updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditGroupInfoPage(group: group),
              ),
            );

            if (updated == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group info updated.')),
              );

              // Pop the group page so it fully refreshes
              Navigator.of(context).pop(); 
            }
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.group),
          title: const Text('Manage Members'),
          onTap: () {
            context.push('/groups/${group.id}/members');
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.announcement),
          title: const Text('Manage Announcements'),
          onTap: () {
            context.push('/groups/${group.id}/announcements');
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.announcement),
          title: const Text('Manage Events'),
          onTap: () {
            context.push('/groups/${group.id}/events');
          },
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.calendar_month),
          title: const Text('Manage Group Calendar'),
          onTap: () {
            context.push('/groups/${group.id}/events');
          },
        ),
        const SizedBox(height: 24),

        PrimaryButton(
          title: 'Request Group Deletion',
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => GroupDeletionRequestModal(groupId: group.id),
            );
          },
        ),
      ],
    );
  }
}
