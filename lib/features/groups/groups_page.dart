// file: lib/features/groups/groups_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'your_groups_section.dart';
import 'joinable_groups_section.dart';
import 'invitations_section.dart';
import 'package:easy_localization/easy_localization.dart';

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
    FocusScope.of(context).unfocus();

    final nameController = TextEditingController();
    final descController = TextEditingController();
    String visibility = 'invite_only';
    bool creating = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: !creating,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => GestureDetector(
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: AlertDialog(
            title: Text("key_052".tr()), // Create Group
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: "key_052a".tr()), // Name
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(labelText: "key_052b".tr()), // Description
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: visibility,
                    decoration: InputDecoration(
                      labelText: "key_052c".tr(), // Visibility
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(32)),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    items: [
                      DropdownMenuItem(value: 'invite_only', child: Text("key_053".tr())), // Invite only
                      DropdownMenuItem(value: 'public', child: Text("key_054".tr())), // Public
                      DropdownMenuItem(value: 'request', child: Text("Request")), // add i18n key if you have one
                    ],
                    onChanged: creating
                        ? null
                        : (val) => setLocal(() => visibility = val ?? visibility),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: creating ? null : () => Navigator.pop(ctx, false),
                child: Text("key_055".tr()), // Cancel
              ),
              ElevatedButton(
                onPressed: creating
                    ? null
                    : () async {
                        setLocal(() => creating = true);
                        final name = nameController.text.trim();
                        final desc = descController.text.trim();

                        if (name.length < 3) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text("key_056".tr())), // Name too short
                          );
                          setLocal(() => creating = false);
                          return;
                        }

                        try {
                          final client = Supabase.instance.client;
                          final userId = client.auth.currentUser?.id;
                          if (userId == null) throw Exception('User not logged in');

                          // Create group (explicit defaults; defensive)
                          final groupInsert = await client
                              .from('groups')
                              .insert({
                                'name': name,
                                'description': desc.isEmpty ? null : desc,
                                'visibility': visibility,            // 'invite_only' | 'public' | 'request'
                                'temporary': false,
                                'archived': false,
                              })
                              .select('id')
                              .single();

                          final groupId = groupInsert['id'] as String;

                          // Make creator the owner
                          await client.from('group_memberships').insert({
                            'group_id': groupId,
                            'user_id': userId,
                            'role': 'owner',
                            'status': 'approved',
                            'joined_at': DateTime.now().toUtc().toIso8601String(),
                          });

                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on PostgrestException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed to create group: $e')),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setLocal(() => creating = false);
                        }
                      },
                child: creating
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text("key_058".tr()), // Create
              ),
            ],
          ),
        ),
      ),
    );

    if (created == true && mounted) {
      await _refreshAllSections();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_group_created".tr(args: []),)), // add localization key if desired
      );
    }
  }

  Future<void> _loadUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loadingRole = false);
      return;
    }

    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _userRole = res?['role'];
        _loadingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (_loadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "key_058a".tr(), // Please sign in to see and join groups.
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: (_userRole == 'owner')
          ? FloatingActionButton.extended(
              onPressed: _openCreateGroupDialog,
              icon: const Icon(Icons.add),
              label: Text("key_059".tr()), // Create Group
            )
          : null,
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
