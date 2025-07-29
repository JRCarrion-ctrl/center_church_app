import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/features/groups/pages/group_join_page.dart';

class JoinableGroupsSection extends StatefulWidget {
  const JoinableGroupsSection({super.key});

  @override
  State<JoinableGroupsSection> createState() => JoinableGroupsSectionState();
}

class JoinableGroupsSectionState extends State<JoinableGroupsSection> {
  List<GroupModel> allGroups = [];
  List<GroupModel> filteredGroups = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFilteredGroups();
  }

  void refresh() => _loadFilteredGroups();

  Future<void> _loadFilteredGroups() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final joinable = await GroupService().getJoinableGroups();

    final memberships = await client
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'approved');

    final joinedIds = (memberships as List)
        .map((m) => m['group_id'] as String)
        .toSet();

    allGroups = joinable.where((g) => !joinedIds.contains(g.id)).toList();
    _applyFilter();
    setState(() => _loading = false);
  }

  void _applyFilter() {
    setState(() {
      filteredGroups = allGroups.where((g) => g.name.toLowerCase().contains(_query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Groups You Can Join', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search groups...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          onChanged: (val) {
            _query = val;
            _applyFilter();
          },
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredGroups.isEmpty)
          const Text('No open groups available at the moment.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredGroups.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final group = filteredGroups[index];
              return GestureDetector(
                onTap: () => showGroupJoinModal(context, group.id),
                child: Hero(
                  tag: 'group-${group.id}',
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: group.photoUrl != null
                                ? NetworkImage(group.photoUrl!)
                                : null,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: group.photoUrl == null
                                ? const Icon(Icons.group, size: 28, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            group.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (group.description != null && group.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                group.description!,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
