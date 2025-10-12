// file: lib/features/groups/groups_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'your_groups_section.dart';
import 'joinable_groups_section.dart';
import 'invitations_section.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/shared/user_roles.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _yourGroupsKey = GlobalKey<YourGroupsSectionState>();
  final _joinableGroupsKey = GlobalKey<JoinableGroupsSectionState>();
  final _invitationsKey = GlobalKey<InvitationsSectionState>();

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
                    initialValue: visibility,
                    decoration: InputDecoration(
                      labelText: "key_052c".tr(), // Visibility
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(32)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    items: [
                      DropdownMenuItem(value: 'invite_only', child: Text("key_053".tr())), // Invite only
                      DropdownMenuItem(value: 'public', child: Text("key_054".tr())),      // Public
                      DropdownMenuItem(value: 'request', child: Text("Request")),           // TODO: i18n
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

                        final app = context.read<AppState>();
                        final userId = app.profile?.id;
                        if (userId == null || userId.isEmpty) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text("key_058a".tr())), // Please sign in...
                            );
                          }
                          setLocal(() => creating = false);
                          return;
                        }

                        // Hasura mutation: create group and make creator owner (nested insert)
                        const mCreate = r'''
                          mutation CreateGroup($name: String!, $desc: String, $vis: String!, $uid: String!) {
                            insert_groups_one(
                              object: {
                                name: $name,
                                description: $desc,
                                visibility: $vis,
                                temporary: false,
                                archived: false,
                                group_memberships: {
                                  data: [{
                                    user_id: $uid,
                                    role: "owner",
                                    status: "approved",
                                    joined_at: "now()"
                                  }]
                                }
                              }
                            ) { id }
                          }
                        ''';

                        try {
                          final client = GraphProvider.of(context);
                          final res = await client.mutate(
                            MutationOptions(
                              document: gql(mCreate),
                              variables: {
                                'name': name,
                                'desc': desc.isEmpty ? null : desc,
                                'vis': visibility,
                                'uid': userId,
                              },
                              fetchPolicy: FetchPolicy.noCache,
                            ),
                          );

                          if (res.hasException) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(res.exception.toString())),
                              );
                            }
                            setLocal(() => creating = false);
                            return;
                          }

                          if (ctx.mounted) Navigator.pop(ctx, true);
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
        SnackBar(content: Text("key_group_created".tr(args: []))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isAuthed = app.isAuthenticated;
    final isOwner = app.userRole == UserRole.owner;

    if (!isAuthed) {
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
      floatingActionButton: isOwner
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
