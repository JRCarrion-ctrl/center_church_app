// File: lib/features/groups/group_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/group.dart';
import 'group_service.dart';
import 'widgets/group_calendar_tab.dart';
import 'widgets/admin_tools_widget.dart';
import 'widgets/group_chat_tab.dart';
import 'widgets/group_media_tab.dart';

class GroupPage extends StatefulWidget {
  final String groupId;

  const GroupPage({super.key, required this.groupId});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> with SingleTickerProviderStateMixin {
  late Future<void> _initFuture;
  Group? _group;
  bool _isAdmin = false;

  late List<Tab> _tabs;
  late List<Widget> _tabViews;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    final group = await GroupService().getGroupById(widget.groupId);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final isAdmin = await GroupService().isUserGroupAdmin(widget.groupId, userId);

    _group = group;
    _isAdmin = isAdmin;

    _tabs = [
      const Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
      const Tab(icon: Icon(Icons.calendar_today), text: 'Calendar'),
      const Tab(icon: Icon(Icons.perm_media), text: 'Media'),
    ];
    _tabViews = [
      GroupChatTab(groupId: widget.groupId, isAdmin: _isAdmin),
      GroupCalendarTab(groupId: widget.groupId),
      GroupMediaTab(groupId: widget.groupId),
    ];

    if (_isAdmin) {
      _tabs.add(const Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admin'));
      _tabViews.add(AdminToolsWidget(group: group!));
    }

    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_group == null || snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Failed to load group.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_group!.name),
            leading: BackButton(onPressed: () => Navigator.of(context).pop()),
            bottom: TabBar(controller: _tabController, tabs: _tabs),
          ),
          body: TabBarView(controller: _tabController, children: _tabViews),
        );
      },
    );
  }
}
