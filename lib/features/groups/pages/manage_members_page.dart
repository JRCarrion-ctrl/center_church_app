// File: lib/features/groups/pages/manage_members_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../group_service.dart';
import '../widgets/invite_user_modal.dart';

class ManageMembersPage extends StatefulWidget {
  final String groupId;

  const ManageMembersPage({
    super.key,
    required this.groupId,
  });

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  late Future<List<Map<String, dynamic>>> _futureMembers;
  late Future<List<Map<String, dynamic>>> _futurePending;
  late Future<List<Map<String, dynamic>>> _futureInvitations;
  late GroupService _groups;
  bool _inited = false;
  bool _isAdmin = false;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      _checkAdminRole();
    }
    if (_inited) return;
    _inited = true;
    final client = GraphProvider.of(context);
    _groups = GroupService(client);
    
    // Initialize all futures
    _futureMembers = _groups.getGroupMembers(widget.groupId);
    
    // Incoming requests (users asking to join)
    _futurePending = _isAdmin
        ? _groups.getGroupJoinRequests(widget.groupId)
        : Future.value([]); 
        
    // Outgoing invitations (users invited by an admin)
    _futureInvitations = _isAdmin
        ? _groups.getPendingMembers(widget.groupId)
        : Future.value([]);
  }

  Future<void> _checkAdminRole() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    if (userId != null) {
      final service = GroupService(GraphProvider.of(context));
      final role = await service.getMyGroupRole(groupId: widget.groupId, userId: userId);
      if (mounted) {
        setState(() {
          _isAdmin = const {'leader', 'supervisor', 'owner', 'admin'}.contains(role) || appState.userRole.name == 'owner';
        });
      }
    }
  }

  // --- Centralized Refresh Logic ---
  Future<void> _refreshAllLists() async {
    final updatedMembers = _groups.getGroupMembers(widget.groupId);
    final updatedPending = _isAdmin
        ? _groups.getGroupJoinRequests(widget.groupId)
        : Future.value(<Map<String, dynamic>>[]); 
    final updatedInvitations = _isAdmin
        ? _groups.getPendingMembers(widget.groupId)
        : Future.value(<Map<String, dynamic>>[]);

    if (!mounted) return;
    setState(() {
      _futureMembers = updatedMembers;
      _futurePending = updatedPending;
      _futureInvitations = updatedInvitations;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final myUserId = context.watch<AppState>().profile?.id;

    return Scaffold(
      appBar: AppBar(title: Text("key_144".tr())),
      floatingActionButton: _isAdmin 
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: InviteUserModal(groupId: widget.groupId),
                    ),
                  ),
                ).then((_) {
                  if (mounted) _refreshAllLists();
                });
              },
              child: const Icon(Icons.person_add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshAllLists,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Approved Members ---
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureMembers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final members = snapshot.data ?? [];
                  if (members.isEmpty) return Text("key_146".tr());

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("key_145".tr()), // Approved Members
                      ...members.map((m) => _buildMemberTile(m, myUserId)),
                    ],
                  );
                },
              ),
              
              if (_isAdmin) ...[
                const SizedBox(height: 32),

                // --- Incoming Join Requests ---
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futurePending,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) return const SizedBox();
                    
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Error loading requests: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      );
                    }

                    final pending = snapshot.data ?? [];
                    if (pending.isEmpty) return const SizedBox();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("key_146a".tr()), // Pending Requests
                        ...pending.map((m) => _buildPendingTile(m)),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                // --- Outgoing Invitations ---
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futureInvitations,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) return const SizedBox();
                    
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Error loading invitations: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      );
                    }

                    final invites = snapshot.data ?? [];
                    if (invites.isEmpty) return const SizedBox();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Pending Invitations".tr()), // Use an existing translation key if you have one
                        ...invites.map((i) => _buildInviteTile(i)),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, String? myUserId) {
    final isCurrentUser = (myUserId != null && myUserId == member['user_id']);
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
        if (!_isAdmin || isCurrentUser) return;

        final myRole = await _groups.getMyGroupRole(
          groupId: widget.groupId,
          userId: myUserId,
        );

        final targetRole = member['role'] as String;
        final targetId = member['user_id'] as String;

        final roleHierarchy = {
          'member': 1,
          'admin': 2,
          'leader': 3,
          'supervisor': 4,
          'owner': 5,
        };

        final myLevel = roleHierarchy[myRole] ?? 0;
        final targetLevel = roleHierarchy[targetRole] ?? 0;

        if (myLevel <= targetLevel || myLevel < 2) return;

        final actions = <PopupMenuEntry<String>>[];
        actions.add(PopupMenuItem(value: 'remove', child: Text("key_147".tr())));

        if (myRole == 'leader' || myRole == 'supervisor' || myRole == 'owner' || myRole == 'admin') {
          if (targetRole == 'member') {
            actions.add(PopupMenuItem(value: 'promote', child: Text("key_148".tr())));
          } else if (targetRole == 'admin' && myRole != 'admin') { 
             actions.add(PopupMenuItem(value: 'demote', child: Text("key_149".tr())));
          }
        }
        
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
              messenger.showSnackBar(SnackBar(content: Text('${member['display_name']} removed')));
            }
          } else if (selected == 'promote') {
            await _groups.setMemberRole(widget.groupId, targetId, 'admin');
            if (!mounted) return;
            await _refreshAllLists();
            messenger.showSnackBar(SnackBar(content: Text('${member['display_name']} promoted to admin')));
          } else if (selected == 'demote') {
            await _groups.setMemberRole(widget.groupId, targetId, 'member');
            if (!mounted) return;
            await _refreshAllLists();
            messenger.showSnackBar(SnackBar(content: Text('${member['display_name']} demoted to member')));
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
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
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () async {
                try {
                  final messenger = ScaffoldMessenger.of(context);
                  await _groups.approveMemberRequest(
                    widget.groupId,
                    member['user_id'] as String,
                  );
                  if (!mounted) return;
                  await _refreshAllLists();
                  messenger.showSnackBar(SnackBar(content: Text('${member['display_name']} approved.')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approve failed: $e')));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Deny',
              onPressed: () async {
                try {
                  final messenger = ScaffoldMessenger.of(context);
                  await _groups.denyMemberRequest(
                    widget.groupId,
                    member['user_id'] as String,
                  );
                  if (!mounted) return;
                  await _refreshAllLists();
                  messenger.showSnackBar(SnackBar(content: Text('${member['display_name']} denied.')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deny failed: $e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteTile(Map<String, dynamic> invite) {
    final photoUrl = invite['photo_url'] as String?;
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
              ? CachedNetworkImageProvider(photoUrl)
              : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? const Icon(Icons.mail_outline)
              : null,
        ),
        title: Text(invite['display_name'] ?? invite['email'] ?? 'Pending User'),
        subtitle: Text('Invited as ${invite['role']}'),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined, color: Colors.orange),
          tooltip: 'Revoke Invitation',
          onPressed: () async {
            try {
              final messenger = ScaffoldMessenger.of(context);
              await _groups.removeMember(widget.groupId, invite['user_id'] as String);
              if (!mounted) return;
              await _refreshAllLists();
              messenger.showSnackBar(SnackBar(content: Text('Invitation revoked.')));
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to revoke: $e')));
            }
          },
        ),
      ),
    );
  }
}