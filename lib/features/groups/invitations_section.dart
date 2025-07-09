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

  Future<void> _acceptInvite(GroupModel group) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('group_memberships').insert({
      'group_id': group.id,
      'user_id': userId,
      'role': 'member',
      'status': 'approved',
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });

    await supabase
        .from('group_invitations')
        .delete()
        .eq('group_id', group.id)
        .eq('user_id', userId);

    if (context.mounted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${group.name}')),
      );
      refresh();
    }
  }

  Future<void> _declineInvite(GroupModel group) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('group_invitations')
        .delete()
        .eq('group_id', group.id)
        .eq('user_id', userId);

    if (context.mounted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Declined invitation to ${group.name}')),
      );
      refresh();
    }
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
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (group.description != null && group.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              group.description!,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.check, color: Colors.green),
                              label: const Text('Accept'),
                              onPressed: () => _acceptInvite(group),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Decline'),
                              onPressed: () => _declineInvite(group),
                            ),
                          ],
                        )
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
