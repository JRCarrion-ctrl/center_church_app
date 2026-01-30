// File: lib/features/groups/your_groups_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/features/groups/models/group_model.dart'; // Assume unreadCount is here

class YourGroupsSection extends StatefulWidget {
  const YourGroupsSection({super.key, this.excludeArchived = true});

  /// Hide archived groups defensively at the UI layer
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

  Future<GroupService> _service() async {
    // Prefer the cached instance from AppState; otherwise build with GraphProvider
    final appState = context.read<AppState>();
    return appState.groupService;
  }

  Future<List<GroupModel>> _loadGroups() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    if (userId == null || userId.isEmpty) {
      _allGroups = [];
      _filteredGroups = [];
      return [];
    }

    final groups = await (await _service()).getUserGroups(userId);
    
    // NOTE: GroupModel must be extended in your data layer to include the unread count
    // The getUserGroups query in GroupService must be updated to fetch:
    // (count(messages) where message.created_at > membership.last_seen_at)

    // Defensive filter: hide archived if requested
    final visible = widget.excludeArchived
        ? groups.where((g) => (g.archived) == false).toList()
        : groups;

    // Stable sort by name (consider sorting by unread status first)
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

  Future<void> _openGroup(GroupModel group) async {
    if ((group.archived) == true) {
      return;
    }

    await context.push('/groups/${group.id}');

    if (mounted) {
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLoggedIn = appState.profile != null;

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

        // If not logged in, show a soft message
        if (!isLoggedIn)
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
                
                // Assume 'unreadCount' is a field on GroupModel
                final unreadCount = group.unreadCount; 
                final hasUnread = unreadCount > 0;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openGroup(group),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: (group.photoUrl?.isNotEmpty ?? false)
                                ? NetworkImage(group.photoUrl!)
                                : null,
                            child: (group.photoUrl?.isEmpty ?? true)
                                ? const Icon(Icons.group, size: 30)
                                : null,
                          ),
                          // NEW: Unread message badge
                          if (hasUnread)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error, // Red badge
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  // Display the count, or "9+" if over 9
                                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onError,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    height: 1.0, // Tighten vertical space
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                ),
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