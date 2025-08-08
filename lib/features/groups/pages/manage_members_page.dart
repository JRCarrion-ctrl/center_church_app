import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../group_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

class ManageMembersPage extends StatefulWidget {
  final String groupId;

  const ManageMembersPage({super.key, required this.groupId});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  late Future<List<Map<String, dynamic>>> _futureMembers;

  @override
  void initState() {
    super.initState();
    _futureMembers = GroupService().getGroupMembers(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_144".tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    Text("key_145".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...members.map((m) => _buildMemberTile(m)),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: GroupService().getGroupJoinRequests(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox();
                }

                final pending = snapshot.data ?? [];
                if (pending.isEmpty) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("key_146a".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...pending.map((m) => _buildPendingTile(m)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final isCurrentUser = Supabase.instance.client.auth.currentUser?.id == member['user_id'];
    final photoUrl = member['photo_url'] != null
      ? '${member['photo_url']}?t=${DateTime.now().millisecondsSinceEpoch}'
      : null;

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
        if (isCurrentUser) return;

        final myRole = await GroupService().getMyGroupRole(widget.groupId);
        final targetRole = member['role'] as String;
        final targetId = member['user_id'];

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

        if (myRole == 'leader' || myRole == 'supervisor' || myRole == 'owner') {
          if (targetRole == 'member') {
            actions.add(PopupMenuItem(value: 'promote', child: Text("key_148".tr())));
          } else if (targetRole == 'admin') {
            actions.add(PopupMenuItem(value: 'demote', child: Text("key_149".tr())));
          }
        }

        if (!mounted) return;
        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fill,
          items: actions,
        );

        if (!mounted || selected == null) return;

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
            await GroupService().removeMember(widget.groupId, targetId);
            if (!mounted) return;
            final updated = await GroupService().getGroupMembers(widget.groupId);
            if (!mounted) return;
            setState(() {
              _futureMembers = Future.value(updated);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${member['display_name']} removed')),
            );
          }
        } else if (selected == 'promote') {
          await GroupService().setMemberRole(widget.groupId, targetId, 'admin');
          if (!mounted) return;
          final updated = await GroupService().getGroupMembers(widget.groupId);
          if (!mounted) return;
          setState(() {
            _futureMembers = Future.value(updated);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member['display_name']} promoted to admin')),
          );
        } else if (selected == 'demote') {
          await GroupService().setMemberRole(widget.groupId, targetId, 'member');
          if (!mounted) return;
          final updated = await GroupService().getGroupMembers(widget.groupId);
          if (!mounted) return;
          setState(() {
            _futureMembers = Future.value(updated);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member['display_name']} demoted to member')),
          );
        }
      },
    );
  }

  Widget _buildPendingTile(Map<String, dynamic> member) {
    final photoUrl = member['photo_url'];

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
                await Supabase.instance.client.from('group_memberships').insert({
                  'group_id': widget.groupId,
                  'user_id': member['user_id'],
                  'role': 'member',
                  'status': 'approved',
                  'joined_at': DateTime.now().toUtc().toIso8601String(),
                });
                await Supabase.instance.client
                  .from('group_requests')
                  .delete()
                  .eq('group_id', widget.groupId)
                  .eq('user_id', member['user_id']);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Deny',
              onPressed: () async {
                await Supabase.instance.client
                  .from('group_requests')
                  .delete()
                  .eq('group_id', widget.groupId)
                  .eq('user_id', member['user_id']);
              },
            ),
          ],
        ),
      ),
    );
  }
}
