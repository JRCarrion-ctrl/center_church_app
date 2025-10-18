// File: lib/features/groups/pages/group_event_list_page.dart
import 'package:flutter/material.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:go_router/go_router.dart';
import 'package:ccf_app/routes/router_observer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';
import '../../calendar/widgets/group_event_form_modal.dart';

// ✅ STEP 1: Create a data model for the page, like in calendar_page.dart.
class _PageData {
  final List<GroupEvent> events;
  final bool isAdmin;

  _PageData({required this.events, required this.isAdmin});
}

class GroupEventListPage extends StatefulWidget {
  final String groupId;

  const GroupEventListPage({super.key, required this.groupId});

  @override
  State<GroupEventListPage> createState() => _GroupEventListPageState();
}

class _GroupEventListPageState extends State<GroupEventListPage> with RouteAware {
  // ✅ STEP 2: Use a single Future to manage the page's entire state.
  late Future<_PageData> _pageDataFuture;
  late EventService _service;
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    if (!_bootstrapped) {
      _bootstrapped = true;
      final gql = GraphProvider.of(context);
      _service = EventService(gql);
      _pageDataFuture = _loadPageData(); // Initial data load
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh data when returning to this page
    _refreshData();
  }

  // ✅ STEP 3: Create a single function to load all necessary data.
  Future<_PageData> _loadPageData() async {
    try {
      // Run fetches in parallel for better performance
      final results = await Future.wait([
        _service.fetchGroupEvents(widget.groupId),
        _checkAdminRole(),
      ]);

      final events = results[0] as List<GroupEvent>;
      final isAdmin = results[1] as bool;

      return _PageData(events: events, isAdmin: isAdmin);
    } catch (e) {
      // Propagate error to the FutureBuilder
      rethrow;
    }
  }

  Future<void> _refreshData() {
    setState(() {
      _pageDataFuture = _loadPageData();
    });
    return _pageDataFuture;
  }

  // This function now returns a boolean instead of setting state directly.
  Future<bool> _checkAdminRole() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    if (userId == null) return false;

    // ✅ SIMPLIFIED: Call the new service method. No more GraphQL in the page!
    final isAdmin = await _service.isUserAdminInGroup(
      groupId: widget.groupId,
      userId: userId,
    );
  
    // You can also check for a global owner role here if needed
    final isOwnerGlobally = appState.userRole.name == 'owner';
  
    return isAdmin || isOwnerGlobally;
  }

  Future<void> _openFormModal({GroupEvent? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroupEventFormModal(
        existing: existing,
        groupId: widget.groupId,
      ),
    );

    // Refresh data only if the form indicated a change was made
    if (result == true) {
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ STEP 4: Build the UI from the state of the single Future.
    return FutureBuilder<_PageData>(
      future: _pageDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isAdmin = data?.isAdmin ?? false;

        return Scaffold(
          appBar: AppBar(title: Text("key_070".tr())),
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: () => _openFormModal(),
                  tooltip: "key_070a".tr(),
                  child: const Icon(Icons.add),
                )
              : null,
          body: _buildBody(snapshot),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<_PageData> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading events: ${snapshot.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text("Retry".tr()),
            )
          ],
        ),
      );
    }

    final events = snapshot.data!.events;
    final isAdmin = snapshot.data!.isAdmin;

    if (events.isEmpty) {
      return Center(child: Text("key_071".tr()));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: events.length,
        itemBuilder: (_, i) => _buildEventTile(events[i], isAdmin),
      ),
    );
  }

  Widget _buildEventTile(GroupEvent e, bool isAdmin) {
    final count = e.attendingCount ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/group-event/${e.id}', extra: e),
        leading: (e.imageUrl != null && e.imageUrl!.isNotEmpty)
            ? Image.network(
                e.imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              )
            : const Icon(Icons.event, size: 40),
        title: Row(
          children: [
            Expanded(child: Text(e.title)),
            if (isAdmin)
              PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'edit') {
                    await _openFormModal(existing: e);
                  } else if (action == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text("key_072".tr()),
                        content: Text("key_073".tr()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text("key_074".tr()),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text("key_075".tr()),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.deleteEvent(e.id);
                      _refreshData();
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text("key_076".tr())),
                  PopupMenuItem(value: 'delete', child: Text("key_077".tr())),
                ],
              ),
          ],
        ),
        subtitle: Text(
          '${TimeService.formatUtcToLocal(e.eventDate)}\n$count attending',
        ),
      ),
    );
  }
}