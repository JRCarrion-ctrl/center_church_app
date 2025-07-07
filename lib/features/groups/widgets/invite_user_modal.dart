import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteUserModal extends StatefulWidget {
  final String groupId;
  const InviteUserModal({super.key, required this.groupId});

  @override
  State<InviteUserModal> createState() => _InviteUserModalState();
}

class _InviteUserModalState extends State<InviteUserModal> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) return;
    setState(() => _loading = true);

    try {
      final publicUsers = await _supabase
          .from('public_profiles')
          .select('id, display_name, email')
          .ilike('email', '%$query%');

      final membershipRows = await _supabase
          .from('group_memberships_summary')
          .select('user_id, group_id')
          .eq('group_id', widget.groupId);

      final pendingInvites = await _supabase
          .from('group_invitations')
          .select('user_id')
          .eq('group_id', widget.groupId)
          .eq('status', 'pending');

      final memberIds = {
        for (final m in membershipRows) m['user_id'] as String,
      };
      final invitedIds = {
        for (final i in pendingInvites) i['user_id'] as String,
      };

      final enrichedResults = publicUsers.map((user) {
        final id = user['id'] as String;
        return {
          ...user,
          'isMember': memberIds.contains(id),
          'isInvited': invitedIds.contains(id),
        };
      }).toList();

      setState(() {
        _results = List<Map<String, dynamic>>.from(enrichedResults);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _sendInvite(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    await _supabase.from('group_invitations').insert({
      'group_id': widget.groupId,
      'user_id': userId,
      'status': 'pending',
    });
    await _searchUsers(_searchController.text);
    messenger.showSnackBar(
      const SnackBar(content: Text('Invitation sent')),
    );
  }

  Future<void> _cancelInvite(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    await _supabase
        .from('group_invitations')
        .delete()
        .eq('group_id', widget.groupId)
        .eq('user_id', userId)
        .eq('status', 'pending');
    await _searchUsers(_searchController.text);
    messenger.showSnackBar(
      const SnackBar(content: Text('Invitation canceled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Invite Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(labelText: 'Search by email'),
            onChanged: _searchUsers,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ..._results.map((user) => ListTile(
              title: Text(user['display_name']),
              subtitle: Text(user['email']),
              trailing: user['isMember'] == true
                  ? null
                  : user['isInvited'] == true
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _cancelInvite(user['id']),
                        )
                      : IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () => _sendInvite(user['id']),
                        ),
            )),
        ],
      ),
    );
  }
}
