// file: lib/features/more/pages/family_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../more/models/invite_modal.dart';

class FamilyPage extends StatefulWidget {
  final String? familyId;

  const FamilyPage({super.key, required this.familyId});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  final supabase = Supabase.instance.client;
  final logger = Logger();
  List<Map<String, dynamic>> members = [];
  bool isLoading = true;
  String? error;
  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    if (user == null) {
      context.go('/landing');
      return;
    }
    currentUserId = user.id;
    if (widget.familyId != null) {
      _loadFamily();
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.familyId != null && members.isEmpty) {
      _loadFamily();
    }
  }

  Future<void> _loadFamily() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final familyId = widget.familyId;
    if (familyId == null) {
      setState(() {
        isLoading = false;
        error = 'No family ID provided';
      });
      return;
    }

    try {
      final result = await supabase
          .from('family_members')
          .select('*, user:profiles!family_members_user_id_fkey(*), inviter:profiles!family_members_invited_by_fkey(*), child:child_profiles(*)')
          .eq('family_id', familyId);

      logger.i('Fetched family members: count=${result.length}');
      for (var m in result) {
        logger.d({'member': m});
      }

      setState(() => members = List<Map<String, dynamic>>.from(result));
    } catch (e, stack) {
      logger.e('Failed to load family members', error: e, stackTrace: stack);
      setState(() => error = 'Failed to load family members');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _createFamily() async {
    final response = await supabase.from('families').insert({}).select('id').single();
    final newFamilyId = response['id'];

    await supabase.from('family_members').insert({
      'user_id': currentUserId,
      'family_id': newFamilyId,
      'relationship': 'Self',
      'is_child': false,
      'status': 'accepted',
    });

    if (mounted) {
      context.go('/more/family', extra: {
        'familyId': newFamilyId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.familyId == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/more')),
          title: const Text("Your Family"),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("You are not in a family yet."),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createFamily,
                child: const Text("Create Family"),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadInvites,
                child: const Text("View Family Invites"),
              ),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final self = members.where((m) => m['user']?['id'] == currentUserId).toList();
    final children = members.where((m) => m['is_child'] == true).toList();
    final adults = members.where((m) => m['is_child'] != true && m['user']?['id'] != currentUserId).toList();
    final pending = members.where((m) => m['status'] == 'pending').toList();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/more')),
        title: const Text("Your Family"),
        actions: [
          IconButton(
            icon: const Icon(Icons.child_care),
            onPressed: _addChild,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _inviteUser,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamily,
        child: members.isEmpty
            ? ListView(children: [SizedBox(height: 200, child: Center(child: Text("No family members found.")))])
            : ListView(
                children: [
                  if (self.isNotEmpty) _buildSection("You", self),
                  if (children.isNotEmpty) _buildSection("Your Children", children),
                  if (adults.isNotEmpty) _buildSection("Family Members", adults),
                  if (pending.isNotEmpty) _buildSection("Pending Invites", pending),
                ],
              ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: items.map(_buildMemberTile).toList(),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> m) {
    final isChild = m['is_child'] == true;
    final status = m['status'] ?? 'accepted';
    final user = m['user'];
    final child = m['child'];
    final displayName = user?['display_name'] ?? child?['display_name'] ?? 'Unnamed';
    final photoUrl = user?['photo_url'] ?? child?['photo_url'];
    final relationship = m['relationship'] ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? Icon(isChild ? Icons.child_care : Icons.person)
            : null,
      ),
      title: Text(displayName),
      subtitle: Wrap(
        spacing: 6,
        children: [
          if (relationship.isNotEmpty) Chip(label: Text(relationship)),
          if (status == 'pending') Chip(label: const Text('Pending'), backgroundColor: Colors.orange.shade100),
        ],
      ),
      onTap: () {
        if (isChild && child != null) {
          context.pushNamed('view_child_profile', extra: child['id']);
        } else if (user != null) {
          context.push("/profile/${user['id']}");
        }
      },
    );
  }

  void _inviteUser() {
    if (widget.familyId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteExistingUserModal(
        familyId: widget.familyId!,
        invitedBy: currentUserId,
      ),
    );
  }

  void _addChild() {
    if (widget.familyId != null) {
      context.pushNamed('add_child_profile', extra: widget.familyId);
    }
  }

  Future<void> _loadInvites() async {
    final result = await supabase
        .from('family_members')
        .select('*, user:profiles(*)')
        .eq('linked_user_id', currentUserId)
        .eq('status', 'pending');

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Family Invites'),
          content: result.isEmpty
              ? const Text('You have no pending invitations.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: result.map<Widget>((invite) {
                    final inviter = invite['user'];
                    final name = inviter?['display_name'] ?? 'Someone';
                    return ListTile(
                      title: Text('Invited by $name'),
                      subtitle: Text(invite['relationship'] ?? 'No relationship'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _respondToInvite(invite['id'], true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _respondToInvite(invite['id'], false),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _respondToInvite(String id, bool accept) async {
    if (accept) {
      await supabase.from('family_members').update({'status': 'accepted'}).eq('id', id);

      final updated = await supabase
          .from('family_members')
          .select('family_id')
          .eq('id', id)
          .maybeSingle();

      final newFamilyId = updated?['family_id'];
      if (mounted && newFamilyId != null) {
        context.go('/more/family', extra: {
          'familyId': newFamilyId,
        });
        return;
      }
    } else {
      await supabase.from('family_members').delete().eq('id', id);
    }
    if (mounted) {
      Navigator.pop(context);
      _showSnackbar(accept ? 'Joined family!' : 'Invite declined');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
