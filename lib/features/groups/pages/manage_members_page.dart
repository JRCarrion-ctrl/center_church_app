// File: lib/features/groups/pages/manage_members_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../group_service.dart';

class ManageMembersPage extends StatefulWidget {
  final String groupId;
  final bool isAdmin; // <-- ADDED: Flag from GroupInfoPage/Router

  const ManageMembersPage({
    super.key,
    required this.groupId,
    this.isAdmin = false, // Default to false for safety
  });

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  late Future<List<Map<String, dynamic>>> _futureMembers;
  late Future<List<Map<String, dynamic>>> _futurePending;
  late GroupService _groups;
  // late GraphQLClient _gql; // GQL client is only used internally by GroupService
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final client = GraphProvider.of(context);
    _groups = GroupService(client);
    
    // Initialize both futures
    _futureMembers = _groups.getGroupMembers(widget.groupId);
    _futurePending = widget.isAdmin
        ? _groups.getGroupJoinRequests(widget.groupId)
        : Future.value([]); // Don't fetch if not admin
  }

  // --- Centralized Refresh Logic ---
  Future<void> _refreshAllLists() async {
    final updatedMembers = _groups.getGroupMembers(widget.groupId);
    final updatedPending = widget.isAdmin
        ? _groups.getGroupJoinRequests(widget.groupId)
        : Future.value(<Map<String, dynamic>>[]); 

    if (!mounted) return;
    setState(() {
      _futureMembers = updatedMembers;
      _futurePending = updatedPending;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final myUserId = context.watch<AppState>().profile?.id;

    return Scaffold(
      appBar: AppBar(title: Text("key_144".tr())),
      body: RefreshIndicator(
        onRefresh: _refreshAllLists,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Approved Members ---
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureMembers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final members = snapshot.data ?? [];
                  if (members.isEmpty) return Text("key_146".tr());

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("key_145".tr(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...members.map((m) => _buildMemberTile(m, myUserId)),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 32),

              // --- Pending Requests (Only visible if isAdmin is true) ---
              if (widget.isAdmin) 
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futurePending,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      // Don't show progress if members are still loading, wait until they're done
                      return const SizedBox(); 
                    }

                    final pending = snapshot.data ?? [];
                    if (pending.isEmpty) return const SizedBox();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("key_146a".tr(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...pending.map((m) => _buildPendingTile(m)),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, String? myUserId) {
    final isCurrentUser = (myUserId != null && myUserId == member['user_id']);
    // Note: If photoUrl is set with a query param of the current time, 
    // you don't need to append it here if the GroupMembers query already returned fresh URLs.
    // If photos are cached aggressively, keeping the timestamp is fine.
    final photoUrl = member['photo_url'] as String?;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(member['display_name'] + (isCurrentUser ? ' (You)' : '')),
      subtitle: Text(member['role']),
      onTap: () => context.push('/profile/${member['user_id']}'),
      onLongPress: () async {
        // SECURITY FIX 1: Only allow long press if the current user is an admin
        if (!widget.isAdmin || isCurrentUser) return;

        final myRole = await _groups.getMyGroupRole(
          groupId: widget.groupId,
          userId: myUserId,
        );

        final targetRole = member['role'] as String;
        final targetId = member['user_id'] as String;

        // Role hierarchy check ensures an admin can't promote/demote a higher-level user
        // and provides a general restriction (level < 2 is member).
        final roleHierarchy = {
          'member': 1,
          'admin': 2,
          'leader': 3,
          'supervisor': 4,
          'owner': 5,
        };

        final myLevel = roleHierarchy[myRole] ?? 0;
        final targetLevel = roleHierarchy[targetRole] ?? 0;

        // Block if user is trying to target someone of equal or higher level,
        // or if the user isn't an admin/leader/owner (level >= 2)
        if (myLevel <= targetLevel || myLevel < 2) return;

        final actions = <PopupMenuEntry<String>>[];
        actions.add(PopupMenuItem(value: 'remove', child: Text("key_147".tr())));

        if (myRole == 'leader' || myRole == 'supervisor' || myRole == 'owner' || myRole == 'admin') {
          if (targetRole == 'member') {
            actions.add(PopupMenuItem(value: 'promote', child: Text("key_148".tr())));
          } else if (targetRole == 'admin' && myRole != 'admin') { // Admin can only demote other admins if they are higher rank (leader/owner)
             actions.add(PopupMenuItem(value: 'demote', child: Text("key_149".tr())));
          }
        }
        
        // Final check to see if any actions were added before showing the menu
        if (actions.isEmpty) return;


        if (!mounted) return;
        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fill,
          items: actions,
        );

        if (!mounted || selected == null) return;

        try {
          final messenger = ScaffoldMessenger.of(context);
          if (selected == 'remove') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text("key_150".tr()),
                content: Text('Are you sure you want to remove ${member['display_name']}?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("key_152".tr())),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("key_153".tr())),
                ],
              ),
            );
            if (confirm == true) {
              await _groups.removeMember(widget.groupId, targetId);
              if (!mounted) return;
              await _refreshAllLists();
              messenger.showSnackBar(
                SnackBar(content: Text('${member['display_name']} removed')),
              );
            }
          } else if (selected == 'promote') {
            await _groups.setMemberRole(widget.groupId, targetId, 'admin');
            if (!mounted) return;
            await _refreshAllLists();
            messenger.showSnackBar(
              SnackBar(content: Text('${member['display_name']} promoted to admin')),
            );
          } else if (selected == 'demote') {
            await _groups.setMemberRole(widget.groupId, targetId, 'member');
            if (!mounted) return;
            await _refreshAllLists();
            messenger.showSnackBar(
              SnackBar(content: Text('${member['display_name']} demoted to member')),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action failed: $e')),
          );
        }
      },
    );
  }

  Widget _buildPendingTile(Map<String, dynamic> member) {
    final photoUrl = member['photo_url'] as String?;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
              ? CachedNetworkImageProvider(photoUrl)
              : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? const Icon(Icons.person_outline)
              : null,
        ),
        title: Text(member['display_name'] ?? 'Unnamed'),
        subtitle: Text(member['email'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Approve
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () async {
                try {
                  final messenger = ScaffoldMessenger.of(context);
                  // FIX 2: Use GroupService method instead of inline GraphQL
                  await _groups.approveMemberRequest(
                    widget.groupId,
                    member['user_id'] as String,
                  );
                  if (!mounted) return;
                  await _refreshAllLists();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${member['display_name']} approved.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Approve failed: $e')),
                  );
                }
              },
            ),
            // Deny
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Deny',
              onPressed: () async {
                try {
                  final messenger = ScaffoldMessenger.of(context);
                  // FIX 2: Use GroupService method instead of inline GraphQL
                  await _groups.denyMemberRequest(
                    widget.groupId,
                    member['user_id'] as String,
                  );
                  if (!mounted) return;
                  await _refreshAllLists();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${member['display_name']} denied.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deny failed: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}