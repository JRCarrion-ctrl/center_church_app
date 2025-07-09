// File: lib/features/groups/your_groups_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';

class YourGroupsSection extends StatefulWidget {
  const YourGroupsSection({super.key});

  @override
  State<YourGroupsSection> createState() => YourGroupsSectionState();
}

class YourGroupsSectionState extends State<YourGroupsSection> {
  late Future<List<GroupModel>> _futureGroups;

  @override
  void initState() {
    super.initState();
    _futureGroups = _loadGroups();
  }

  Future<List<GroupModel>> _loadGroups() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return GroupService().getUserGroups(userId);
  }

  /// Public method to allow refresh from parent
  Future<void> refresh() async {
    setState(() {
      _futureGroups = _loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Groups',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<GroupModel>>(
          future: _futureGroups,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Text('Error loading your groups: ${snapshot.error}');
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return const Text('You are not in any groups yet.');
            }

            return SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return GestureDetector(
                    onTap: () {
                      context.push('/groups/${group.id}');
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: group.photoUrl != null
                              ? NetworkImage(group.photoUrl!)
                              : null,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: group.photoUrl == null
                              ? const Icon(Icons.group, size: 30, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: Text(
                            group.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
