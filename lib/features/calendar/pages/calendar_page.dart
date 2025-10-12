// filename: calendar_page.dart
import 'package:ccf_app/shared/user_roles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/routes/router_observer.dart';

import '../../../app_state.dart';
import '../event_service.dart';
import '../models/group_event.dart';
import '../models/app_event.dart';
import '../widgets/app_event_form_modal.dart';
import '../../more/models/calendar_settings_modal.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with RouteAware {
  late Future<_CalendarData> _calendarFuture;
  // REMOVED: bool _canManageApp = false; // Now calculated synchronously in build

  String _refreshKey = UniqueKey().toString();

  late EventService _eventService;
  bool _svcReady = false;

  @override
  void initState() {
    super.initState();
    // initState remains empty as the initial service setup is in didChangeDependencies
  }

  // DELETED: Future<void> _checkPermissions() async { ... } 
  // The role check is now done via Provider in the build method.

  Future<_CalendarData> _loadAllEvents() async {
    final appState = context.read<AppState>();

    // uses the ready service
    final appEvents = await _eventService.fetchAppEvents();

    List<GroupEvent> filteredGroupEvents = [];
    final currentUserId = appState.profile?.id;

    if (currentUserId != null && appState.visibleCalendarGroupIds.isNotEmpty) {
      final groupEvents = await _eventService.fetchUpcomingGroupEvents();
      final visibleGroupIds = appState.visibleCalendarGroupIds.toSet();
      filteredGroupEvents =
          groupEvents.where((e) => visibleGroupIds.contains(e.groupId)).toList();
    }

    return _CalendarData(appEvents: appEvents, groupEvents: filteredGroupEvents);
  }

  Future<void> _openAppForm([AppEvent? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppEventFormModal(existing: existing),
    );
    setState(() => _calendarFuture = _loadAllEvents());
  }

  void _openCalendarSettings() {
    CalendarSettingsModal.show(context).then((_) {
      setState(() {
        _calendarFuture = _loadAllEvents();
        _refreshKey = UniqueKey().toString();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // FIX 1: Memory Leak Fix - Always unsubscribe before subscribing
    routeObserver.unsubscribe(this);

    // subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    // initialize EventService once we have inherited widgets
    if (!_svcReady) {
      final client = GraphQLProvider.of(context).value;
      final userId = context.read<AppState>().profile?.id;
      _eventService = EventService(client, currentUserId: userId);
      _svcReady = true;

      // now safe to load events
      _calendarFuture = _loadAllEvents();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // refresh when returning to this page
    setState(() {
      _calendarFuture = _loadAllEvents();
      _refreshKey = UniqueKey().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AppState, bool>((s) => s.profile?.id != null);
    
    // FIX 2: Synchronous Role Check for button visibility
    final userRole = context.select<AppState, UserRole?>((s) => s.userRole);
    final bool canManageApp = userRole == UserRole.supervisor || userRole == UserRole.owner;

    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder<_CalendarData>(
            future: _calendarFuture,
            key: Key(_refreshKey),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text("key_035".tr()));
              }

              final appEvents = snap.data!.appEvents;
              final groupEvents = snap.data!.groupEvents;

              if (appEvents.isEmpty && groupEvents.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _calendarFuture = _loadAllEvents();
                      _refreshKey = UniqueKey().toString();
                    });
                    await _calendarFuture;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 200),
                      Center(child: Text("key_036".tr())),
                    ],
                  ),
                );
              }

              final List<Widget> items = [];

              if (appEvents.isNotEmpty) {
                items.add(_sectionHeader("key_036a".tr()));
                // Pass the permission down to the card builder
                items.addAll(appEvents.map(_buildAppEventCard(isLoggedIn, canManageApp)));
              }

              if (groupEvents.isNotEmpty) {
                items.add(_sectionHeader("key_036b".tr()));
                items.addAll(groupEvents.map(_buildGroupEventCard));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _calendarFuture = _loadAllEvents();
                    _refreshKey = UniqueKey().toString();
                  });
                  await _calendarFuture;
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: items,
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'calendar-settings',
              onPressed: _openCalendarSettings,
              tooltip: 'Manage Calendars',
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      // Use the local 'canManageApp' boolean
      floatingActionButton: canManageApp
          ? FloatingActionButton(
              onPressed: () => _openAppForm(),
              tooltip: "key_036c".tr(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );

  // Updated function signature to accept canManageApp
  Widget Function(AppEvent) _buildAppEventCard(bool isLoggedIn, bool canManageApp) =>
      (AppEvent e) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: !isLoggedIn
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("key_037".tr())),
                      )
                  : () => context.push('/app-event/${e.id}', extra: e),
              // Use the passed 'canManageApp' boolean
              trailing: canManageApp
                  ? PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await _openAppForm(e);
                        } else if (action == 'delete') {
                          await _eventService.deleteAppEvent(e.id);
                          setState(() => _calendarFuture = _loadAllEvents());
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text("key_038".tr())),
                        PopupMenuItem(value: 'delete', child: Text("key_039".tr())),
                      ],
                    )
                  : null,
              leading: e.imageUrl != null
                  ? Image.network(
                      e.imageUrl!,
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.announcement, size: 40),
              title: Text(e.title),
              subtitle: Text(
                TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a'),
              ),
            ),
          );

  Widget _buildGroupEventCard(GroupEvent e) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: () => context.push('/group-event/${e.id}', extra: e),
          leading: e.imageUrl != null
              ? Image.network(
                  e.imageUrl!,
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.event, size: 40),
          title: Text(e.title),
          subtitle: Text(
            TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a'),
          ),
        ),
      );
}

class _CalendarData {
  final List<AppEvent> appEvents;
  final List<GroupEvent> groupEvents;
  _CalendarData({required this.appEvents, required this.groupEvents});
}