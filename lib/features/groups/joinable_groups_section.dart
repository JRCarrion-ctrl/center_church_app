import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/group_service.dart';

class JoinableGroupsSection extends StatefulWidget {
  const JoinableGroupsSection({super.key});

  @override
  State<JoinableGroupsSection> createState() => _JoinableGroupsSectionState();
}

class _JoinableGroupsSectionState extends State<JoinableGroupsSection> {
  late Future<List<GroupModel>> _futureGroups;

  @override
  void initState() {
    super.initState();
    _futureGroups = GroupService().getJoinableGroups();
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
