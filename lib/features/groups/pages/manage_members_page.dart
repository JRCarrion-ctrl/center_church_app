import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageMembersPage extends StatefulWidget {
  final String groupId;

  const ManageMembersPage({super.key, required this.groupId});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchGroupMembers() async {
    final data = await supabase
        .from('group_memberships')
        .select('user_id, role, profiles(display_name)')
        .eq('group_id', widget.groupId)
        .eq('status', 'approved')
        .order('profiles.display_name', ascending: true);

    return List<Map<String, dynamic>>.from(data.map((e) => {
          'user_id': e['user_id'],
          'role': e['role'],
          'display_name': e['profiles']?['display_name'] ?? 'Unnamed User',
        }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Members'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchGroupMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return const Center(child: Text('No members found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final member = members[index];

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(member['display_name']),
                subtitle: Text(member['role']),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tapped ${member['display_name']}')),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
