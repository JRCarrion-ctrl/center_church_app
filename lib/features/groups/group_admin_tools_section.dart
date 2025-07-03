import 'package:flutter/material.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupAdminToolsSection extends StatefulWidget {
  const GroupAdminToolsSection({super.key});

  @override
  State<GroupAdminToolsSection> createState() => _GroupAdminToolsSectionState();
}

class _GroupAdminToolsSectionState extends State<GroupAdminToolsSection> {
  late Future<List<GroupModel>> _adminGroups;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _adminGroups = GroupService().getAdminGroups(userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupModel>>(
      future: _adminGroups,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        if (snapshot.hasError) {
          return Text('Error loading admin tools');
        }

        final adminGroups = snapshot.data ?? [];

        if (adminGroups.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group Admin Tools',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Manage Groups'),
                onTap: () {
                  // Navigate to group admin panel
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
