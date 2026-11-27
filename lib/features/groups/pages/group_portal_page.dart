// File: lib/features/groups/pages/group_portal_page.dart
import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/app_state.dart';

import '../group_service.dart';
import '../widgets/group_dashboard_tab.dart';
import '../widgets/group_chat_tab.dart';

class GroupPortalPage extends StatefulWidget {
  final String groupId;
  
  const GroupPortalPage({super.key, required this.groupId});

  @override
  State<GroupPortalPage> createState() => _GroupPortalPageState();
}

class _GroupPortalPageState extends State<GroupPortalPage> {
  late Future<GroupInfoData> _pageDataFuture;
  late GroupService _groupService;
  bool _isInitialized = false;

  bool _isAdmin = false;
  bool _isOwner = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      // 🚀 FIXED: Read the global GroupService directly from the Provider tree!
      _groupService = context.read<GroupService>();
      _pageDataFuture = _loadData();
    }
  }

  Future<GroupInfoData> _loadData() async {
    // 1. Fetch the group data
    final groupData = await _groupService.getGroupInfoData(widget.groupId);
    
    // 2. Figure out the user's role natively
    // ignore: use_build_context_synchronously
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    
    if (userId != null && mounted) {
      final role = await _groupService.getMyGroupRole(groupId: widget.groupId, userId: userId);
      setState(() {
        _isAdmin = const {'leader', 'supervisor', 'owner', 'admin'}.contains(role) || appState.userRole.name == 'owner';
        _isOwner = appState.userRole.name == 'owner';
      });
    }
    
    return groupData;
  }

  Future<void> _refreshData() async {
    setState(() {
      _pageDataFuture = _groupService.getGroupInfoData(widget.groupId);
    });
    await _pageDataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupInfoData>(
      future: _pageDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/groups'); // Fallback to the Groups tab
                  }
                },
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("key_086".tr()), // "Error loading group"
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _refreshData, child: Text("Retry".tr())),
                ],
              ),
            ),
          );
        }

        final pageData = snapshot.data!;
        // Sub-groups only get a Chat tab — no Home tab, so there's no way to
        // create a sub-group within a sub-group (nesting is intentionally
        // unsupported since sub-groups have no parent/child column of their own).
        final isSubGroup = pageData.group.parentGroupId != null;

        return DefaultTabController(
          length: isSubGroup ? 1 : 2,
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/groups'); // Fallback to the Groups tab
                  }
                },
              ),
              centerTitle: false,
              titleSpacing: 0,
              title: _GroupTitle(
                name: pageData.group.name,
                photoUrl: pageData.group.photoUrl,
              ),
              // Sub-groups have no Home tab (that's where the Members button
              // normally lives), so give admins a direct way to manage members.
              actions: isSubGroup
                  ? [
                      IconButton(
                        icon: const Icon(Icons.people_outline),
                        tooltip: "Members",
                        onPressed: () => context.push('/groups/${widget.groupId}/info/members'),
                      ),
                      if (_isAdmin)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Subgroup'),
                                  content: const Text('Are you sure? This will archive the subgroup.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true), 
                                      child: const Text('Delete', style: TextStyle(color: Colors.red))
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true && mounted) {
                                try {
                                  await _groupService.deleteGroup(widget.groupId);
                                  if (!context.mounted) return;
                                  if (mounted) context.pop(); // Return to the parent group
                                } catch (e) {
                                  if (mounted) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete: $e'))
                                    );
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Subgroup', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                    ]
                  : null,
              bottom: isSubGroup
                  ? null
                  : const PreferredSize(
                      preferredSize: Size.fromHeight(56),
                      child: _PillTabBar(),
                    ),
            ),
            body: TabBarView(
              children: [
                GroupChatTab(
                  groupId: widget.groupId,
                  isAdmin: _isAdmin,
                  onlyAdminsCanMessage: pageData.group.onlyAdminsMessage,
                ),
                if (!isSubGroup)
                  GroupDashboardTab(
                    pageData: pageData,
                    isAdmin: _isAdmin,
                    isOwner: _isOwner,
                    onRefresh: _refreshData,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ✨ The Invisible Invite Processor
class GroupInviteProcessorScreen extends StatefulWidget {
  final String groupId;
  final String? token;

  const GroupInviteProcessorScreen({super.key, required this.groupId, this.token});

  @override
  State<GroupInviteProcessorScreen> createState() => _GroupInviteProcessorScreenState();
}

class _GroupInviteProcessorScreenState extends State<GroupInviteProcessorScreen> {
  @override
  void initState() {
    super.initState();
    _processInvite();
  }

  Future<void> _processInvite() async {
    if (widget.token == null) {
      _showErrorAndGoHome("Invalid invite link.");
      return;
    }

    // 🚀 FIXED: Standardized the GraphQL client fetch to match the rest of your app
    final client = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;

    if (userId == null) {
      _showErrorAndGoHome("You must be logged in.");
      return;
    }

    // 1. Verify the token matches the group
    const qVerify = r'''
      query VerifyToken($groupId: uuid!, $token: String!) {
        groups(where: {id: {_eq: $groupId}, invite_token: {_eq: $token}}) {
          id
        }
      }
    ''';

    final verifyRes = await client.query(QueryOptions(
      document: gql(qVerify),
      variables: {'groupId': widget.groupId, 'token': widget.token},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (verifyRes.hasException || (verifyRes.data?['groups'] as List).isEmpty) {
      _showErrorAndGoHome("This invite link has expired or is invalid.");
      return;
    }

    // 2. Add the user to the group
    const mJoin = r'''
      mutation JoinGroup($groupId: uuid!, $userId: String!) {
        insert_group_memberships_one(
          object: {group_id: $groupId, user_id: $userId, status: "approved", role: "member"}
          on_conflict: {constraint: group_memberships_pkey, update_columns: [status]}
        ) {
          group_id
        }
      }
    ''';

    await client.mutate(MutationOptions(
      document: gql(mJoin),
      variables: {'groupId': widget.groupId, 'userId': userId},
    ));

    // 3. Force AppState to refresh the user's groups so it shows up in their UI
    if (mounted) {
      await context.read<AppState>().loadUserGroups();
      
      // 4. Drop them right into the group portal!
      if (!mounted) return;
      context.go('/groups/${widget.groupId}');
    }
  }

  void _showErrorAndGoHome(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text("Joining group...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Group photo + name in the app bar.
class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = photoUrl?.isNotEmpty ?? false;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
          child: hasPhoto ? null : Icon(Icons.groups_outlined, size: 20, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}

/// Chat | Home as a rounded segmented control, matching the landing page.
class _PillTabBar extends StatelessWidget {
  const _PillTabBar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(22),
        ),
        child: TabBar(
          dividerColor: colorScheme.surface.withValues(alpha: 0),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18),
                  const SizedBox(width: 8),
                  Text('groups_tab_chat'.tr()),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.space_dashboard_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('groups_tab_home'.tr()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
