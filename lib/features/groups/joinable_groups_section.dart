import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/group_service.dart';


class JoinableGroupsSection extends StatefulWidget {
  const JoinableGroupsSection({super.key});

  @override
  State<JoinableGroupsSection> createState() => JoinableGroupsSectionState();
}

class JoinableGroupsSectionState extends State<JoinableGroupsSection> {
  late Future<List<GroupModel>> _futureGroups;

  @override
  void initState() {
    super.initState();
    _futureGroups = _loadFilteredGroups();
  }

  void refresh() {
    setState(() {
      _futureGroups = _loadFilteredGroups();
    });
  }

  Future<List<GroupModel>> _loadFilteredGroups() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final allJoinable = await GroupService().getJoinableGroups();

    final memberships = await client
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'approved');

    final joinedGroupIds = (memberships as List)
        .map((m) => m['group_id'] as String)
        .toSet();

    return allJoinable.where((g) => !joinedGroupIds.contains(g.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Groups You Can Join',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<GroupModel>>(
          future: _futureGroups,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return const Text('No open groups available at the moment.');
            }

            return Column(
              children: groups.map((group) {
                return Card(
                  child: ListTile(
                    title: Text(group.name),
                    subtitle: group.description != null
                        ? Text(group.description!)
                        : null,
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => context.push('/groups/${group.id}/join'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
