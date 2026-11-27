import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import 'your_groups_section.dart';
import 'joinable_groups_section.dart';
import 'invitations_section.dart';
import 'models/group_model.dart';
import 'group_service.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/shared/user_roles.dart';
import 'package:ccf_app/shared/widgets/glass.dart';
import 'package:ccf_app/shared/page_refresh.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> with AutoRefresh<GroupsPage> {
  final _yourGroupsKey = GlobalKey<YourGroupsSectionState>();
  final _joinableGroupsKey = GlobalKey<JoinableGroupsSectionState>();
  final _invitationsKey = GlobalKey<InvitationsSectionState>();
  late Future<List<GroupModel>> _invitesFuture;
  bool _futuresInitialized = false;
  List<String>? _lastServiceFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final app = context.watch<AppState>(); // Listen for changes
    final service = context.read<GroupService>();
    final userId = app.profile?.id;

    // 1. One-time setup for Invites (since they don't depend on language)
    if (!_futuresInitialized) {
      _invitesFuture = userId != null 
          ? service.getGroupInvitations(userId) 
          : Future.value([]);
      _futuresInitialized = true;
    }

    // 2. Refresh Joinable Groups when the TCCF / Centro choice changes.
    final filter = app.databaseServiceFilter;
    if (_lastServiceFilter != null && _lastServiceFilter!.join(',') != filter.join(',')) {
      _joinableGroupsKey.currentState?.refresh();
    }
    _lastServiceFilter = List.of(filter);
  }

  @override
  Future<void> onAutoRefresh() => _refreshAllSections();

  Future<void> _refreshAllSections() async {
    final userId = context.read<AppState>().profile?.id;
    if (userId != null) {
      setState(() => _invitesFuture = context.read<GroupService>().getGroupInvitations(userId));
    }
    _yourGroupsKey.currentState?.refresh();
    _joinableGroupsKey.currentState?.refresh();
    _invitationsKey.currentState?.refresh();
  }

  Future<void> _openCreateGroupDialog() async {
    FocusScope.of(context).unfocus();

    final nameController = TextEditingController();
    final descController = TextEditingController();
    String visibility = 'invite_only';
    
    // ✨ NEW: State for the new group's language tags
    List<String> selectedAudiences = ['english', 'spanish']; 
    bool creating = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: !creating,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => GestureDetector(
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text("key_052".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: "key_052a".tr(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: "key_052b".tr(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  
                  // ✨ NEW: Target Audience Selector
                  Text(
                    "Target Audience".tr(), 
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['english', 'spanish'].map((lang) {
                      final isSelected = selectedAudiences.contains(lang);
                      return FilterChip(
                        label: Text(lang == 'english' ? 'TCCF' : 'Centro'),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setLocal(() {
                            if (selected) {
                              selectedAudiences.add(lang);
                            } else {
                              selectedAudiences.remove(lang);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: visibility,
                    decoration: InputDecoration(
                      labelText: "key_052c".tr(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: [
                      DropdownMenuItem(value: 'invite_only', child: Text("key_053".tr())),
                      DropdownMenuItem(value: 'public', child: Text("key_054".tr())),
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
                child: Text("key_055".tr()),
              ),
              ElevatedButton(
                onPressed: (creating || selectedAudiences.isEmpty)
                    ? null
                    : () async {
                        setLocal(() => creating = true);

                        final name = nameController.text.trim();
                        final desc = descController.text.trim();
                        
                        // Validation
                        if (name.length < 3) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("key_056".tr())));
                          setLocal(() => creating = false);
                          return;
                        }

                        final userId = context.read<AppState>().profile?.id;
                        
                        // ✨ UPDATED MUTATION: Added target_audiences
                        const mCreate = r'''
                          mutation CreateGroup($name: String!, $desc: String, $vis: String!, $uid: String!, $langs: [String!]!) {
                            insert_groups_one(
                              object: {
                                name: $name,
                                description: $desc,
                                visibility: $vis,
                                temporary: false,
                                archived: false,
                                target_audiences: $langs,
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
                                'langs': selectedAudiences, // ✨ PASS THE ARRAY
                              },
                              fetchPolicy: FetchPolicy.noCache,
                            ),
                          );

                          if (res.hasException) throw res.exception!;
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text("key_058".tr()),
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
        SnackBar(content: Text("key_057a".tr(args: []))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isAuthed = app.isAuthenticated;
    final isOwner = app.userRole == UserRole.owner;
    
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // --- START: Updated check for logged out user with better UI ---
    if (!isAuthed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 48, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  "key_058a".tr(), // Please sign in to see and join groups.
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
                ),
                const SizedBox(height: 8),
                Text(
                  "key_058b".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    // Navigate to the authentication route
                    context.push('/auth');
                  }, 
                  icon: const Icon(Icons.login), 
                  label: Text("key_017".tr()), // Assuming key_017 is "Log In" or similar
                ),
              ],
            ),
          ),
        ),
      );
    }
    // --- END: Updated check for logged out user with better UI ---

    return Scaffold(
      floatingActionButton: isOwner ? _buildSleekFAB() : null,
      body: RefreshIndicator(
        onRefresh: _refreshAllSections,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Same photo + glass look as the landing page and Events tab.
                    PhotoHeader(
                      title: "key_065".tr(), // Your Groups
                      subtitle: 'groups_subtitle'.tr(),
                      height: 140,
                    ),
                    const SizedBox(height: 16),

                    // 1. INVITATIONS (only when there are some)
                    FutureBuilder<List<GroupModel>>(
                      future: _invitesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _SectionCard(
                              child: InvitationsSection(key: _invitationsKey, onInviteHandled: _refreshAllSections),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // 2. YOUR GROUPS (chat list)
                    YourGroupsSection(key: _yourGroupsKey),

                    // 3. GROUPS YOU CAN JOIN (hides itself when there are none)
                    const SizedBox(height: 28),
                    JoinableGroupsSection(
                      key: _joinableGroupsKey,
                      onGroupJoined: _refreshAllSections,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleekFAB() {
    return FloatingActionButton.extended(
      onPressed: _openCreateGroupDialog,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      elevation: 4,
      // Using the StadiumBorder ensures the "pill" shape matches your landing page buttons
      shape: const StadiumBorder(),
      icon: const Icon(Icons.add),
      label: Text("key_059".tr()), // Create Group
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
