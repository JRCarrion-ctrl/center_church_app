// File: lib/features/groups/invitations_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';

class InvitationsSection extends StatefulWidget {
  final VoidCallback? onInviteHandled;

  const InvitationsSection({
    super.key, 
    this.onInviteHandled,
  });

  @override
  State<InvitationsSection> createState() => InvitationsSectionState();
}

class InvitationsSectionState extends State<InvitationsSection> {
  List<GroupModel> _invites = [];
  bool _loading = true;
  
  // This tracks which card is expanded to show Accept/Decline buttons
  String? _expandedGroupId;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  void refresh() => _loadInvitations();

  Future<void> _loadInvitations() async {
    setState(() => _loading = true);

    final userId = context.read<AppState>().profile?.id;
    if (userId == null || userId.isEmpty) {
      setState(() {
        _invites = [];
        _loading = false;
      });
      return;
    }

    // Access service from AppState
    final svc = context.read<AppState>().groupService;
    final invites = await svc.getGroupInvitations(userId);

    if (!mounted) return;
    setState(() {
      _invites = invites;
      _loading = false;
    });
  }

  GraphQLClient _client() => GraphProvider.of(context);

  Future<void> _acceptInvite(GroupModel group) async {
    final userId = context.read<AppState>().profile?.id;
    if (userId == null || userId.isEmpty) return;

    const m = r'''
      mutation AcceptInvite($gid: uuid!, $uid: String!) {
        insert_group_memberships_one(
          object: {
            group_id: $gid
            user_id: $uid
            role: "member"
            status: "approved"
            joined_at: "now()"
          },
          on_conflict: {
            constraint: group_memberships_pkey,
            update_columns: [status, role, joined_at]
          }
        ) { group_id }
        delete_group_invitations(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        ) { affected_rows }
      }
    ''';

    final res = await _client().mutate(
      MutationOptions(
        document: gql(m),
        variables: {'gid': group.id, 'uid': userId},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (!mounted) return;

    if (res.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_012'))), // General error
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('key_060', args: [group.name]))), // "Joined {group}"
    );

    setState(() {
      // Safe removal by ID
      _invites.removeWhere((g) => g.id == group.id);
      _expandedGroupId = null;
    });

    // Notify parent to refresh "Your Groups"
    widget.onInviteHandled?.call();
  }

  Future<void> _declineInvite(GroupModel group) async {
    final userId = context.read<AppState>().profile?.id;
    if (userId == null || userId.isEmpty) return;

    const m = r'''
      mutation DeclineInvite($gid: String!, $uid: String!) {
        delete_group_invitations(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        ) { affected_rows }
      }
    ''';

    final res = await _client().mutate(
      MutationOptions(
        document: gql(m),
        variables: {'gid': group.id, 'uid': userId},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (!mounted) return;

    if (res.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_012'))),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('key_061', args: [group.name]))), // "Declined invitation..."
    );

    setState(() {
      // Safe removal by ID
      _invites.removeWhere((g) => g.id == group.id);
      _expandedGroupId = null;
    });
    
    // Notify parent (optional, but keeps state clean)
    widget.onInviteHandled?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // If no invites, hide the section entirely
    if (_invites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "key_059a".tr(), // "Invitations"
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _invites.length,
          itemBuilder: (context, index) {
            final group = _invites[index];
            
            // This uses the _expandedGroupId variable
            final isExpanded = _expandedGroupId == group.id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      setState(() {
                        // Toggle expansion state
                        _expandedGroupId = isExpanded ? null : group.id;
                      });
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      backgroundImage: (group.photoUrl != null && group.photoUrl!.isNotEmpty)
                          ? NetworkImage(group.photoUrl!)
                          : null,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: (group.photoUrl == null || group.photoUrl!.isEmpty)
                          ? const Icon(Icons.group, color: Colors.white)
                          : null,
                    ),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: (group.description != null && group.description!.isNotEmpty)
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
                  
                  // If expanded, show the buttons that call the "unused" methods
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _acceptInvite(group), // Called here
                            icon: const Icon(Icons.check),
                            label: Text("key_059b".tr()), // Accept
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _declineInvite(group), // Called here
                            icon: const Icon(Icons.close),
                            label: Text("key_059c".tr()), // Decline
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}