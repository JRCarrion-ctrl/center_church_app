import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
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
  bool _canManageApp = false;
  String _refreshKey = UniqueKey().toString();
  final user = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _calendarFuture = _loadAllEvents();
  }

  Future<void> _checkPermissions() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final res = await client.from('profiles').select('role').eq('id', user.id).single();
    final role = res['role'] as String?;
    setState(() {
      _canManageApp = role == 'supervisor' || role == 'owner';
    });
  }

  Future<_CalendarData> _loadAllEvents() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final service = EventService();
    final appEvents = await service.fetchAppEvents();

    List<GroupEvent> filteredGroupEvents = [];

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && appState.visibleCalendarGroupIds.isNotEmpty) {
      final groupEvents = await service.fetchUpcomingGroupEvents();
      final visibleGroupIds = appState.visibleCalendarGroupIds.toSet();
      filteredGroupEvents = groupEvents.where((e) => visibleGroupIds.contains(e.groupId)).toList();
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
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {
      _calendarFuture = _loadAllEvents();
      _refreshKey = UniqueKey().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                return Center(child: Text('Error: ${snap.error}'));
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
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No upcoming events.')),
                    ],
                  ),
                );
              }

              final List<Widget> items = [];

              if (appEvents.isNotEmpty) {
                items.add(_sectionHeader('App-Wide Events'));
                items.addAll(appEvents.map(_buildAppEventCard));
              }

              if (groupEvents.isNotEmpty) {
                items.add(_sectionHeader('Your Group Events'));
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
      floatingActionButton: _canManageApp
          ? FloatingActionButton(
              onPressed: () => _openAppForm(),
              tooltip: 'Add App Event',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _buildAppEventCard(AppEvent e) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: user == null
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to view event details.')),
                )
              : () => context.push('/app-event/${e.id}', extra: e),
          trailing: _canManageApp
              ? PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _openAppForm(e);
                    } else if (action == 'delete') {
                      await EventService().deleteAppEvent(e.id);
                      setState(() => _calendarFuture = _loadAllEvents());
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
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
          subtitle: Text(TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a')),
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
          subtitle: Text(TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a')),
        ),
      );
}

class _CalendarData {
  final List<AppEvent> appEvents;
  final List<GroupEvent> groupEvents;
  _CalendarData({required this.appEvents, required this.groupEvents});
}