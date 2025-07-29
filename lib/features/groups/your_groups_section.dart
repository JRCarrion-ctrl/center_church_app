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
  List<GroupModel> _allGroups = [];
  List<GroupModel> _filteredGroups = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _futureGroups = _loadGroups();
  }

  Future<List<GroupModel>> _loadGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final groups = await GroupService().getUserGroups(userId);
    _allGroups = groups;
    _filteredGroups = groups;
    return groups;
  }

  /// Public method to allow refresh from parent
  Future<void> refresh() async {
    setState(() {
      _futureGroups = _loadGroups();
    });
  }

  void _filterGroups(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredGroups = _allGroups.where((g) => g.name.toLowerCase().contains(_searchQuery)).toList();
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
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search groups',
          ),
          onChanged: _filterGroups,
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

            if (_filteredGroups.isEmpty) {
              return const Text('You are not in any groups yet.');
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredGroups.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final group = _filteredGroups[index];
                return GestureDetector(
                  onTap: () => context.push('/groups/${group.id}'),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'group_avatar_${group.id}',
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: group.photoUrl != null ? NetworkImage(group.photoUrl!) : null,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: group.photoUrl == null
                              ? const Icon(Icons.group, size: 30, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: SizedBox(
                          width: 72,
                          child: Text(
                            group.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
