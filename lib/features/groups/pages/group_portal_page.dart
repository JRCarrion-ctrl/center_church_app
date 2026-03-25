// File: lib/features/groups/pages/group_portal_page.dart
import 'package:flutter/material.dart';
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
            appBar: AppBar(),
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

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(pageData.group.name),
              bottom: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.space_dashboard_outlined), 
                    text: "Home",
                  ),
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline), 
                    text: "Chat",
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                GroupDashboardTab(
                  pageData: pageData,
                  isAdmin: _isAdmin,
                  isOwner: _isOwner,
                  onRefresh: _refreshData,
                ),
                GroupChatTab(
                  groupId: widget.groupId,
                  isAdmin: _isAdmin,
                  onlyAdminsCanMessage: pageData.group.onlyAdminsMessage,
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