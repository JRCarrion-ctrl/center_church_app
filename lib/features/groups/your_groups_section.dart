// File: lib/features/groups/your_groups_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:easy_localization/easy_localization.dart';

class YourGroupsSection extends StatefulWidget {
  const YourGroupsSection({super.key, this.excludeArchived = true});

  /// Hide archived groups defensively at the UI layer (in case the service
  /// doesn’t filter them yet).
  final bool excludeArchived;

  @override
  State<YourGroupsSection> createState() => YourGroupsSectionState();
}

class YourGroupsSectionState extends State<YourGroupsSection> {
  late Future<List<GroupModel>> _futureGroups;

  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<GroupModel> _allGroups = [];
  List<GroupModel> _filteredGroups = [];

  @override
  void initState() {
    super.initState();
    _futureGroups = _loadGroups();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<List<GroupModel>> _loadGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _allGroups = [];
      _filteredGroups = [];
      return [];
    }

    final groups = await GroupService().getUserGroups(userId);

    // Defensive filter: hide archived if requested
    final visible = widget.excludeArchived
        ? groups.where((g) => (g.archived) == false).toList()
        : groups;

    // Sort by name for a stable grid
    visible.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _allGroups = visible;
    _filteredGroups = _applySearch(_allGroups, _searchCtl.text);
    return _allGroups;
  }

  /// Public method to allow refresh from parent
  Future<void> refresh() async {
    setState(() {
      _futureGroups = _loadGroups();
    });
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _filteredGroups = _applySearch(_allGroups, _searchCtl.text);
      });
    });
  }

  List<GroupModel> _applySearch(List<GroupModel> source, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return List<GroupModel>.from(source);
    return source.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  void _openGroup(GroupModel group) {
    // If an archived group slips through, show a friendly note instead of navigating.
    if ((group.archived) == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('key_group_archived'.tr())), // add i18n
      );
      return;
    }
    context.push('/groups/${group.id}');
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "key_065".tr(), // Your Groups
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: "key_063".tr(), // Search groups...
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // If not logged in, show a soft message (matches your GroupsPage pattern)
        if (user == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              "key_058a".tr(), // Please sign in to see and join groups.
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),

        FutureBuilder<List<GroupModel>>(
          future: _futureGroups,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Text('Error loading your groups: ${snapshot.error}');
            }

            if (_filteredGroups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("key_066".tr()), // You are not in any groups yet.
              );
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
                final archived = group.archived;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openGroup(group),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'group_avatar_${group.id}',
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: (group.photoUrl?.isNotEmpty ?? false)
                              ? NetworkImage(group.photoUrl!)
                              : null,
                          onBackgroundImageError: (_, _) {},
                          child: (group.photoUrl?.isEmpty ?? true)
                              ? const Icon(Icons.group, size: 30, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 72,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                group.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            if (archived) ...[
                              const SizedBox(width: 4),
                              const Tooltip(
                                message: 'Archived',
                                child: Icon(Icons.archive, size: 14),
                              ),
                            ]
                          ],
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
