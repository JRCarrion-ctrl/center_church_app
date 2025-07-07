import 'package:flutter/material.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvitationsSection extends StatefulWidget {
  const InvitationsSection({super.key});

  @override
  State<InvitationsSection> createState() => InvitationsSectionState();
}

class InvitationsSectionState extends State<InvitationsSection> {
  final supabase = Supabase.instance.client;
  late Future<List<GroupModel>> _futureInvites;

  @override
  void initState() {
    super.initState();
    _futureInvites = _loadInvitations();
  }

  Future<List<GroupModel>> _loadInvitations() async {
    final userId = supabase.auth.currentUser?.id ?? '';
    return GroupService().getGroupInvitations(userId);
  }

  void refresh() {
    setState(() {
      _futureInvites = _loadInvitations();
    });
  }

  Future<void> _acceptInvite(String groupId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('group_memberships')
        .update({'status': 'approved'})
        .eq('user_id', userId)
        .eq('group_id', groupId);

    refresh();
  }

  Future<void> _declineInvite(String groupId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('group_memberships')
        .delete()
        .eq('user_id', userId)
        .eq('group_id', groupId);

    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupModel>>(
      future: _futureInvites,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        if (snapshot.hasError) {
          return const Text('Error loading invitations');
        }

        final invites = snapshot.data ?? [];

        if (invites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invitations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...invites.map((group) => Card(
                  child: ListTile(
                    title: Text(group.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _acceptInvite(group.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _declineInvite(group.id),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}
