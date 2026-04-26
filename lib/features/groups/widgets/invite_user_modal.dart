// File: lib/features/groups/widgets/invite_user_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/graph_provider.dart';
import '../group_service.dart'; // Import to use the new method

class InviteUserModal extends StatefulWidget {
  final String groupId;
  const InviteUserModal({super.key, required this.groupId});

  @override
  State<InviteUserModal> createState() => _InviteUserModalState();
}

class _InviteUserModalState extends State<InviteUserModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  
  // Link Generation State
  bool _generatingLink = false;
  String? _generatedLink;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _generateLink() async {
    setState(() => _generatingLink = true);
    try {
      final client = GraphProvider.of(context);
      final svc = GroupService(client);
      
      final link = await svc.generateInviteLink(widget.groupId);
      
      if (!mounted) return;
      setState(() {
        _generatedLink = link;
        _generatingLink = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingLink = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using SingleChildScrollView ensures the dialog doesn't overflow when the keyboard appears
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "key_172a".tr(), // "Invite Users"
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 16),

            // --- LINK GENERATION SECTION ---
            if (_generatedLink != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: _generatedLink!, // This is the URL string!
                      version: QrVersions.auto,
                      size: 150.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _generatedLink!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _generatedLink!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied to clipboard!')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text("Copy Link"),
                        ),
                      ],
                    )
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _generatingLink ? null : _generateLink,
                icon: _generatingLink 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link),
                label: const Text("Generate Invite Link"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),

            // --- DIRECT INVITE SECTION ---
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "key_search_name_email".tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (String query) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  _searchUsers(query);
                });
              },
            ),
            const SizedBox(height: 16),
            
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ))
            else if (_results.isNotEmpty)
              // Constrained list so the dialog doesn't grow indefinitely
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(user['display_name'] ?? ''),
                      subtitle: Text(user['email'] ?? ''),
                      trailing: user['isMember'] == true
                          ? const Icon(Icons.check_circle, color: Colors.grey)
                          : (user['isInvited'] == true
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _cancelInvite(user['id'] as String),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add, color: Colors.green),
                                  onPressed: () => _sendInvite(user['id'] as String),
                                )),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}