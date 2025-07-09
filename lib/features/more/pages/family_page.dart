// file: lib/features/more/pages/family_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../more/models/invite_modal.dart';

class FamilyPage extends StatefulWidget {
  final String familyId;
  final String currentUserId;

  const FamilyPage({super.key, required this.familyId, required this.currentUserId});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> members = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  Future<void> _loadFamily() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await supabase
          .from('family_members')
          .select('*, user:profiles(*), child:child_profiles(*)')
          .eq('family_id', widget.familyId);
      setState(() => members = List<Map<String, dynamic>>.from(result));
    } catch (e) {
      setState(() => error = 'Failed to load family members');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final self = members.where((m) => m['user']?['id'] == widget.currentUserId).toList();
    final children = members.where((m) => m['is_child'] == true).toList();
    final adults = members.where((m) => m['is_child'] != true && m['user']?['id'] != widget.currentUserId).toList();
    final pending = members.where((m) => m['status'] == 'pending').toList();

    return Scaffold(
      appBar: AppBar(
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
      body: ListView(
        children: [
          if (self.isNotEmpty) _buildSection("You", self),
          if (children.isNotEmpty) _buildSection("Your Children", children),
          if (adults.isNotEmpty) _buildSection("Family Members", adults),
          if (pending.isNotEmpty) _buildSection("Pending Invites", pending),
        ],
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteExistingUserModal(
        familyId: widget.familyId,
        invitedBy: widget.currentUserId,
      ),
    );
  }

  void _addChild() {
    context.pushNamed('add_child_profile', extra: widget.familyId);
  }
}