// File: lib/features/groups/widgets/invite_user_modal.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../core/graph_provider.dart';

class InviteUserModal extends StatefulWidget {
  final String groupId;
  const InviteUserModal({super.key, required this.groupId});

  @override
  State<InviteUserModal> createState() => _InviteUserModalState();
}

class _InviteUserModalState extends State<InviteUserModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _searchUsers(String query) async {
    final q = query.trim();
    if (q.length < 2) return;

    setState(() => _loading = true);

    try {
      final client = GraphProvider.of(context);

      // Bundle public profiles + current members + pending invites in one roundtrip.
      const searchOp = r'''
        query InviteUserSearch($gid: uuid!, $searchQuery: String!) {
          public_profiles(
            where: {
              _or: [
                { email: { _ilike: $searchQuery } },
                { display_name: { _ilike: $searchQuery } }
              ]
            }
            limit: 25
          ) {
            id
            display_name
            email
          }
          group_memberships(
            where: {
              group_id: { _eq: $gid }
              status: { _eq: "approved" }
            }
          ) {
            user_id
          }
          group_invitations(
            where: {
              group_id: { _eq: $gid }
              status: { _eq: "pending" }
            }
          ) {
            user_id
          }
        }
      ''';

      final res = await client.query(QueryOptions(
        document: gql(searchOp),
        variables: {
          'gid': widget.groupId,
          'searchQuery': '%$q%',
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (res.hasException) {
        throw res.exception!;
      }

      final profiles = (res.data?['public_profiles'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final memberIds = (res.data?['group_memberships'] as List? ?? [])
          .map((m) => (m as Map<String, dynamic>)['user_id'] as String)
          .toSet();
      final invitedIds = (res.data?['group_invitations'] as List? ?? [])
          .map((m) => (m as Map<String, dynamic>)['user_id'] as String)
          .toSet();

      final enriched = profiles.map((u) {
        final id = u['id'] as String;
        return <String, dynamic>{
          ...u,
          'isMember': memberIds.contains(id),
          'isInvited': invitedIds.contains(id),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _results = enriched;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Search error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _sendInvite(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = GraphProvider.of(context);
      const m = r'''
        mutation InviteUser($gid: uuid!, $uid: String!) {
          insert_group_invitations_one(
            object: { group_id: $gid, user_id: $uid, status: "pending" }
          ) { user_id }
        }
      ''';
      final res = await client.mutate(MutationOptions(
        document: gql(m),
        variables: {'gid': widget.groupId, 'uid': userId},
      ));
      if (res.hasException) throw res.exception!;
      await _searchUsers(_searchController.text);
      messenger.showSnackBar(SnackBar(content: Text("key_171".tr())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to invite: $e')));
    }
  }

  Future<void> _cancelInvite(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = GraphProvider.of(context);
      const m = r'''
        mutation CancelInvite($gid: uuid!, $uid: String!) {
          delete_group_invitations(
            where: {
              group_id: { _eq: $gid }
              user_id: { _eq: $uid }
              status: { _eq: "pending" }
            }
          ) { affected_rows }
        }
      ''';
      final res = await client.mutate(MutationOptions(
        document: gql(m),
        variables: {'gid': widget.groupId, 'uid': userId},
      ));
      if (res.hasException) throw res.exception!;
      await _searchUsers(_searchController.text);
      messenger.showSnackBar(SnackBar(content: Text("key_172".tr())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "key_172a".tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(labelText: "key_172b".tr()),
            onChanged: _searchUsers,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ..._results.map(
              (user) => ListTile(
                title: Text(user['display_name'] ?? ''),
                subtitle: Text(user['email'] ?? ''),
                trailing: user['isMember'] == true
                    ? null
                    : (user['isInvited'] == true
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _cancelInvite(user['id'] as String),
                          )
                        : IconButton(
                            icon: const Icon(Icons.add, color: Colors.green),
                            onPressed: () => _sendInvite(user['id'] as String),
                          )),
              ),
            ),
        ],
      ),
    );
  }
}
