// file: lib/features/groups/groups.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/group.dart';
import 'models/group_invitation.dart';
import 'group_service.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late Future<Map<String, dynamic>> _groupsFuture;

  final userId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
  }

  Future<Map<String, dynamic>> _loadGroups() async {
    final service = GroupService();

    if (userId == null) throw Exception('User not logged in');

    final myGroups = await service.fetchMyGroups(userId!);
    final joinableGroups = await service.fetchJoinableGroups(userId!);
    final invites = await service.fetchInvitations(userId!);

    return {
      'mine': myGroups,
      'joinable': joinableGroups,
      'invites': invites,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final myGroups = snapshot.data!['mine'] as List<Group>;
          final joinable = snapshot.data!['joinable'] as List<Group>;
          final invites = snapshot.data!['invites'] as List<GroupInvitation>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (invites.isNotEmpty) ...[
                const Text('Group Invitations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invites.length,
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    final group = invite.group!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: group.photoUrl != null ? NetworkImage(group.photoUrl!) : null,
                          child: group.photoUrl == null ? const Icon(Icons.group) : null,
                        ),
                        title: Text(group.name),
                        subtitle: invite.note != null ? Text(invite.note!) : null,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await GroupService().acceptInvitation(invite);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Joined ${group.name}')),
                                );
                                setState(() => _groupsFuture = _loadGroups());
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await GroupService().declineInvitation(invite.id);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Declined invite to ${group.name}')),
                                );
                                setState(() => _groupsFuture = _loadGroups());
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              if (myGroups.isNotEmpty) ...[
                const Text('Groups You\'re In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildGroupGrid(myGroups, showJoinButton: false),
                const SizedBox(height: 24),
              ],
              
              if (joinable.isNotEmpty) ...[
                const Text('Groups You Can Join', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildGroupGrid(joinable, showJoinButton: true),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupGrid(List<Group> groups, {required bool showJoinButton}) {
    return GridView.builder(
      itemCount: groups.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final group = groups[index];

        return Column(
          children: [
            GestureDetector(
              onTap: () {
                context.push('/groups/${group.id}');
              },
              child: CircleAvatar(
                radius: 35,
                backgroundImage: group.photoUrl != null
                    ? NetworkImage(group.photoUrl!)
                    : null,
                child: group.photoUrl == null ? const Icon(Icons.group, size: 35) : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(group.name, textAlign: TextAlign.center),
            if (showJoinButton)
              ElevatedButton(
                onPressed: () async {
                  final service = GroupService();
                  final visibility = group.visibility;
                  final action = (visibility == 'public')
                      ? service.joinGroup(group.id, userId!)
                      : service.requestToJoinGroup(group.id, userId!);
                      
                  final messenger = ScaffoldMessenger.of(context);
                  await action;
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(visibility == 'public'
                        ? 'Joined ${group.name}'
                        : 'Requested to join ${group.name}')),
                  );

                  setState(() {
                    _groupsFuture = _loadGroups();
                  });
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: Text(group.visibility == 'public' ? 'Join' : 'Request'),
              ),
          ],
        );
      },
    );
  }
}
