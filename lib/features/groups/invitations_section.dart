import 'package:flutter/material.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class InvitationsSection extends StatefulWidget {
  const InvitationsSection({super.key});

  @override
  State<InvitationsSection> createState() => InvitationsSectionState();
}

class InvitationsSectionState extends State<InvitationsSection> {
  final supabase = Supabase.instance.client;
  List<GroupModel> _invites = [];
  bool _loading = true;
  String? _expandedGroupId;

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
        Text(
          "key_059a".tr(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _invites.length,
          itemBuilder: (context, index) {
            final group = _invites[index];
            final isExpanded = _expandedGroupId == group.id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      setState(() {
                        _expandedGroupId = isExpanded ? null : group.id;
                      });
                    },
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
                    trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _acceptInvite(group);
                              setState(() {
                                _invites.removeAt(index);
                                _expandedGroupId = null;
                              });
                            },
                            icon: const Icon(Icons.check),
                            label: Text("key_059b".tr()),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _declineInvite(group);
                              setState(() {
                                _invites.removeAt(index);
                                _expandedGroupId = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: Text("key_059c".tr()),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }
        ),
      ],
    );
  }
}
