// File: lib/features/groups/invitations_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/group_service.dart';

class InvitationsSection extends StatefulWidget {
  const InvitationsSection({super.key});

  @override
  State<InvitationsSection> createState() => InvitationsSectionState();
}

class InvitationsSectionState extends State<InvitationsSection> {
  List<GroupModel> _invites = [];
  bool _loading = true;
  String? _expandedGroupId;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<GroupService> _svc() async {
    final app = context.read<AppState>();
    return app.groupService;
  }

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

    final svc = await _svc();
    final invites = await svc.getGroupInvitations(userId);

    if (!mounted) return;
    setState(() {
      _invites = invites;
      _loading = false;
    });
  }

  void refresh() => _loadInvitations();

  GraphQLClient _client() => GraphProvider.of(context);

  Future<void> _acceptInvite(GroupModel group) async {
    final userId = context.read<AppState>().profile?.id;
    if (userId == null || userId.isEmpty) return;

    const m = r'''
      mutation AcceptInvite($gid: String!, $uid: String!) {
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

    if (res.hasException) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_error_generic'))),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('key_group_joined', args: [group.name]))),
    );
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

    if (res.hasException) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_error_generic'))),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('key_group_declined', args: [group.name]))),
    );
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
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _acceptInvite(group);
                              if (!mounted) return;
                              setState(() {
                                _invites.removeAt(index);
                                _expandedGroupId = null;
                              });
                            },
                            icon: const Icon(Icons.check),
                            label: Text("key_059b".tr()), // Accept
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _declineInvite(group);
                              if (!mounted) return;
                              setState(() {
                                _invites.removeAt(index);
                                _expandedGroupId = null;
                              });
                            },
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
