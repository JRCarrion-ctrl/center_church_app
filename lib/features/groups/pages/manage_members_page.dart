import 'package:flutter/material.dart';
import '../group_service.dart';
import 'package:go_router/go_router.dart';

class ManageMembersPage extends StatefulWidget {
  final String groupId;

  const ManageMembersPage({super.key, required this.groupId});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  late Future<List<Map<String, dynamic>>> _futureMembers;

  @override
  void initState() {
    super.initState();
    _futureMembers = GroupService().getGroupMembers(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Members'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureMembers,
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
                  context.push('/profile/${member['user_id']}');
                },
              );
            },
          );
        },
      ),
    );
  }
}