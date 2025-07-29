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
  List<GroupModel> _invites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    final userId = supabase.auth.currentUser?.id ?? '';
    final invites = await GroupService().getGroupInvitations(userId);
    setState(() {
      _invites = invites;
      _loading = false;
    });
  }

  void refresh() => _loadInvitations();

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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${group.name}')),
      );
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Declined invitation to ${group.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_invites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invitations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _invites.length,
          itemBuilder: (context, index) {
            final group = _invites[index];

            return Dismissible(
              key: ValueKey(group.id),
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                color: Colors.green,
                child: const Icon(Icons.check, color: Colors.white),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.close, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _acceptInvite(group);
                } else {
                  await _declineInvite(group);
                }
                return true; // Allow Dismissible to remove item
              },
              onDismissed: (_) {
                setState(() {
                  _invites.removeAt(index);
                });
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundImage: group.photoUrl != null ? NetworkImage(group.photoUrl!) : null,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: group.photoUrl == null
                        ? const Icon(Icons.group, color: Colors.white)
                        : null,
                  ),
                  title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: group.description != null && group.description!.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            group.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
