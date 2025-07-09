import 'package:flutter/material.dart';
import 'your_groups_section.dart';
import 'joinable_groups_section.dart';
import 'invitations_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _yourGroupsKey = GlobalKey<YourGroupsSectionState>();
  final _joinableGroupsKey = GlobalKey<JoinableGroupsSectionState>();
  final _invitationsKey = GlobalKey<InvitationsSectionState>();
  String? _userRole;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _refreshAllSections() async {
    _yourGroupsKey.currentState?.refresh();
    _joinableGroupsKey.currentState?.refresh();
    _invitationsKey.currentState?.refresh();
  }

  Future<void> _openCreateGroupDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String visibility = 'invite_only';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: visibility,
              decoration: const InputDecoration(
                labelText: 'Visibility',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(32))),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              borderRadius: BorderRadius.circular(16),
              items: const [
                DropdownMenuItem(value: 'invite_only', child: Text('Invite Only')),
                DropdownMenuItem(value: 'public', child: Text('Public')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => visibility = val);
                }
              },
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();

              if (name.isEmpty) return;

              try {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId == null) throw Exception('User not logged in');

                // 1. Insert group
                final groupInsert = await Supabase.instance.client
                    .from('groups')
                    .insert({
                      'name': name,
                      'description': desc,
                      'visibility': visibility,
                    })
                    .select()
                    .single();

                final groupId = groupInsert['id'];

                // 2. Add current user as group owner
                await Supabase.instance.client
                    .from('group_memberships')
                    .insert({
                      'group_id': groupId,
                      'user_id': userId,
                      'role': 'owner',
                      'status': 'approved',
                      'joined_at': DateTime.now().toUtc().toIso8601String(),
                    });

                if (context.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                debugPrint('Failed to create group: $e');
                if (context.mounted) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create group: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true) {
      await _refreshAllSections();
    }
  }


  Future<void> _loadUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    setState(() {
      _userRole = res?['role'];
      _loadingRole = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAllSections,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YourGroupsSection(key: _yourGroupsKey),
                    const SizedBox(height: 24),
                    JoinableGroupsSection(key: _joinableGroupsKey),
                    const SizedBox(height: 24),
                    InvitationsSection(key: _invitationsKey),
                    const SizedBox(height: 24),
                    if (!_loadingRole && _userRole == 'owner')
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _openCreateGroupDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Group'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
