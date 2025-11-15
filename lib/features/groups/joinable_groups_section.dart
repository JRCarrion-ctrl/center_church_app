// File: lib/features/groups/joinable_groups_section.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
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

  Future<GroupService> _service() async {
    final appState = context.read<AppState>();
    // Assumes AppState has a readily available GroupService instance
    return appState.groupService; 
  }

  Future<void> _loadFilteredGroups() async {
    setState(() => _loading = true);

    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    if (userId == null || userId.isEmpty) {
      setState(() {
        allGroups = [];
        filteredGroups = [];
        _loading = false;
      });
      return;
    }

    final svc = await _service();

    // Hasura-only: get joinable + my groups, then exclude ones I'm already in
    final joinable = await svc.getJoinableGroups();
    final myGroups = await svc.getUserGroups(userId);
    final joinedIds = myGroups.map((g) => g.id).toSet();

    allGroups = joinable.where((g) => !joinedIds.contains(g.id)).toList();

    // Optional stable sort by name
    allGroups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _applyFilter();
    setState(() => _loading = false);
  }

  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    setState(() {
      filteredGroups = q.isEmpty
          ? List<GroupModel>.from(allGroups)
          : allGroups.where((g) => g.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    // === NEW LOGIC: Hide section if no joinable groups AND no active search query ===
    if (allGroups.isEmpty && _query.isEmpty) {
      // If there are no groups to show and the user isn't searching, hide the entire section.
      return const SizedBox.shrink();
    }
    
    // If loading is complete and either groups exist or the user is searching, display the section.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("key_059d".tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: "key_063".tr(),
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          onChanged: (val) {
            _query = val;
            _applyFilter();
          },
        ),
        const SizedBox(height: 16),
        // If groups exist, render the content (either filtered list or "no results" message)
        if (filteredGroups.isEmpty)
          Text("key_064".tr())
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
              final textColor = Theme.of(context).colorScheme.onSurface;
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
                            backgroundImage: (group.photoUrl != null && group.photoUrl!.isNotEmpty)
                                ? NetworkImage(group.photoUrl!)
                                : null,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: (group.photoUrl == null || group.photoUrl!.isEmpty)
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
                                style: TextStyle(fontSize: 12, color: textColor),
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