// File: lib/features/groups/pages/group_event_list_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:go_router/go_router.dart';
import 'package:ccf_app/routes/router_observer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../../calendar/church_event_service.dart';
import '../../calendar/models/church_event.dart';

class _PageData {
  final List<ChurchEvent> events;
  final bool isAdmin;
  final bool isGlobalOwner;
  
  _PageData({
    required this.events, 
    required this.isAdmin, 
    required this.isGlobalOwner,
  });
}

class GroupEventListPage extends StatefulWidget {
  final String groupId;
  const GroupEventListPage({super.key, required this.groupId});

  @override
  State<GroupEventListPage> createState() => _GroupEventListPageState();
}

class _GroupEventListPageState extends State<GroupEventListPage> with RouteAware {
  late Future<_PageData> _pageDataFuture;
  late ChurchEventService _service;
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);

    if (!_bootstrapped) {
      _bootstrapped = true;
      final gql = GraphProvider.of(context);
      final userId = context.read<AppState>().profile?.id;
      _service = ChurchEventService(gql, currentUserId: userId);
      _pageDataFuture = _loadPageData(); 
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _refreshData();

  Future<_PageData> _loadPageData() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;

    if (userId == null) {
      return _PageData(events: [], isAdmin: false, isGlobalOwner: false);
    }

    // Fetch group admin status and global role separately
    final results = await Future.wait([
      _service.fetchEventsForGroup(widget.groupId),
      _service.isUserAdminInGroup(groupId: widget.groupId, userId: userId),
    ]);

    return _PageData(
      events: results[0] as List<ChurchEvent>,
      isAdmin: results[1] as bool,
      isGlobalOwner: appState.userRole.name == 'owner', // Check global state directly
    );
  }

  Future<void> _refreshData() async {
    // Update the future variable first
    final newFuture = _loadPageData();
    
    setState(() {
      _pageDataFuture = newFuture;
    });

    // Wait for it to complete if you need to (e.g., for RefreshIndicator)
    await newFuture;
  }

  Future<void> _navigateToEventForm({ChurchEvent? existing}) async {
    if (existing != null) {
      await context.push('/groups/${widget.groupId}/info/events/edit?eventId=${existing.id}');
    } else {
      await context.push('/groups/${widget.groupId}/info/events/new');
    }
    if (mounted) _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PageData>(
      future: _pageDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isAdmin = data?.isAdmin ?? false;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text("key_070".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _navigateToEventForm(),
                  tooltip: "key_070a".tr(),
                  icon: const Icon(Icons.add),
                  label: const Text("New Event"),
                )
              : null,
          body: _buildBody(snapshot),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<_PageData> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading events', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshData, child: Text("Retry".tr()))
          ],
        ),
      );
    }

    final events = snapshot.data!.events;
    final isAdmin = snapshot.data!.isAdmin;
    final isGlobalOwner = snapshot.data!.isGlobalOwner;
    final colorScheme = Theme.of(context).colorScheme;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text("key_071".tr(), style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final upcomingEvents = events.where((e) => (e.eventEnd ?? e.eventDate.add(const Duration(hours: 1))).toLocal().isAfter(now)).toList();
    final pastEvents = events.where((e) => (e.eventEnd ?? e.eventDate.add(const Duration(hours: 1))).toLocal().isBefore(now)).toList().reversed.toList();

    final List<Widget> items = [];

    if (upcomingEvents.isNotEmpty) {
      items.addAll(upcomingEvents.map((e) => _buildEventTile(e, isAdmin, isGlobalOwner, isPast: false)));
    } else if (pastEvents.isNotEmpty) {
      items.add(Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text("No upcoming events.", style: TextStyle(color: colorScheme.outline)))));
    }

    if (pastEvents.isNotEmpty) {
      items.add(const SizedBox(height: 16));
      items.add(
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4.0),
            title: Text("View Past Events".tr(), style: TextStyle(color: colorScheme.outline, fontWeight: FontWeight.bold)),
            collapsedIconColor: colorScheme.outline,
            iconColor: colorScheme.primary,
            children: pastEvents.map((e) => _buildEventTile(e, isAdmin, isGlobalOwner, isPast: true)).toList(),
          ),
        ),
      );
    }

    return RefreshIndicator(onRefresh: _refreshData, color: colorScheme.primary, child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: items));
  }

  Widget _buildEventTile(ChurchEvent e, bool isGroupAdmin, bool isOwner, {required bool isPast}) {
    final count = e.attendingCount ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Opacity(
        opacity: isPast ? 0.6 : 1.0, 
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          onTap: () => context.push('/group-event/${e.id}'),
          leading: (e.imageUrl != null && e.imageUrl!.isNotEmpty)
              ? ClipRRect( 
                  borderRadius: BorderRadius.circular(12), 
                  child: CachedNetworkImage(
                      imageUrl: e.imageUrl!, width: 50, height: 50, fit: BoxFit.cover,
                      placeholder: (context, url) => Container(width: 50, height: 50, color: colorScheme.surfaceContainerHighest, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      errorWidget: (context, url, error) => Container(width: 50, height: 50, color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image)),
                  ),
                )
              : Container(width: 50, height: 50, decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.event, color: colorScheme.primary)),
          title: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                if (e.isPending) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text('Pending', style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
                if (isGroupAdmin)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert, color: colorScheme.outline, size: 20),
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _navigateToEventForm(existing: e);
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text("key_072".tr()), content: Text("key_073".tr()),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("key_074".tr())),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("key_075".tr())),
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
                  if (isOwner && e.status == 'pending_approval') 
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        await _service.approveEvent(e.id);
                        _refreshData(); // Triggers the fetch again to update the UI
                      },
                    ),
              ],
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a')),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people_alt_outlined, size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('$count attending', style: TextStyle(color: colorScheme.outline, fontSize: 13)),
                  
                  if (e.rrule != null && e.rrule!.contains('FREQ=DAILY')) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.event_repeat, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('Daily', style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}