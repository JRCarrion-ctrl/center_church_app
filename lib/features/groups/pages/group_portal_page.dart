// File: lib/features/groups/pages/group_portal_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/graph_provider.dart';
import '../group_service.dart';
import '../widgets/group_dashboard_tab.dart';
import '../widgets/group_chat_tab.dart';

class GroupPortalPage extends StatefulWidget {
  final String groupId;
  final bool isAdmin;
  final bool isOwner;

  const GroupPortalPage({
    super.key,
    required this.groupId,
    required this.isAdmin,
    required this.isOwner,
  });

  @override
  State<GroupPortalPage> createState() => _GroupPortalPageState();
}

class _GroupPortalPageState extends State<GroupPortalPage> {
  late Future<GroupInfoData> _pageDataFuture;
  late GroupService _groupService;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _groupService = GroupService(GraphProvider.of(context));
      _pageDataFuture = _groupService.getGroupInfoData(widget.groupId);
    }
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
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // 2. Error State
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

        // 3. Main Portal UI
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
                // --- TAB 1: THE NEW DASHBOARD ---
                GroupDashboardTab(
                  pageData: pageData,
                  isAdmin: widget.isAdmin,
                  isOwner: widget.isOwner,
                  onRefresh: _refreshData,
                ),
                
                // --- TAB 2: YOUR EXISTING CHAT ---
                GroupChatTab(
                  groupId: widget.groupId,
                  isAdmin: widget.isAdmin,
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