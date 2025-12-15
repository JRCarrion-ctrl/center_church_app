// filename: calendar_page.dart
import 'package:ccf_app/shared/user_roles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // <--- 1. ADD IMPORT

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
  String _refreshKey = UniqueKey().toString();
  late EventService _eventService;
  bool _svcReady = false;

  // Default to true, but will be overwritten by SharedPreferences
  bool _isCalendarView = true;

  final CalendarController _calendarController = CalendarController();

  @override
  void initState() {
    super.initState();
    // <--- 2. LOAD PREFERENCE ON STARTUP
    _loadViewPreference();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);

    if (!_svcReady) {
      final client = GraphQLProvider.of(context).value;
      final userId = context.read<AppState>().profile?.id;
      _eventService = EventService(client, currentUserId: userId);
      _svcReady = true;
      _calendarFuture = _loadAllEvents();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _calendarController.dispose();
    super.dispose();
  }

  // <--- 3. ADD HELPER TO LOAD STATE
  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // Default to true (Calendar) if no preference is found
        _isCalendarView = prefs.getBool('calendar_is_calendar_view') ?? true;
      });
    }
  }

  // <--- 4. ADD HELPER TO TOGGLE & SAVE STATE
  Future<void> _toggleView() async {
    final newValue = !_isCalendarView;
    setState(() {
      _isCalendarView = newValue;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calendar_is_calendar_view', newValue);
  }

  Future<_CalendarData> _loadAllEvents() async {
    final appState = context.read<AppState>();
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
  void didPopNext() {
    setState(() {
      _calendarFuture = _loadAllEvents();
      _refreshKey = UniqueKey().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.select<AppState, UserRole?>((s) => s.userRole);
    final bool canManageApp = userRole == UserRole.supervisor || userRole == UserRole.owner;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCalendarView ? "key_034".tr() : "key_list_view".tr()), 
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_month),
            tooltip: _isCalendarView ? "Switch to List" : "Switch to Calendar",
            // <--- 5. USE THE NEW TOGGLE METHOD
            onPressed: _toggleView,
          ),
          if (_isCalendarView) ...[
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () {
                _calendarController.displayDate = DateTime.now();
              },
            ),
            PopupMenuButton<CalendarView>(
              icon: const Icon(Icons.view_agenda),
              onSelected: (view) => _calendarController.view = view,
              itemBuilder: (context) => [
                const PopupMenuItem(value: CalendarView.month, child: Text("Month")),
                const PopupMenuItem(value: CalendarView.week, child: Text("Week")),
                const PopupMenuItem(value: CalendarView.schedule, child: Text("Schedule")),
              ],
            ),
          ]
        ],
      ),
      body: FutureBuilder<_CalendarData>(
        future: _calendarFuture,
        key: Key(_refreshKey),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("key_035".tr()));
          }

          final data = snap.data!;
          
          if (_isCalendarView) {
            final dataSource = _EventDataSource(data.appEvents, data.groupEvents, colorScheme);
            return SfCalendar(
              controller: _calendarController,
              view: CalendarView.month,
              dataSource: dataSource,
              initialSelectedDate: DateTime.now(),
              monthViewSettings: const MonthViewSettings(
                appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                showAgenda: true,
              ),
              onTap: (CalendarTapDetails details) {
                if (details.targetElement == CalendarElement.appointment) {
                  if (details.appointments == null || details.appointments!.isEmpty) return;

                  final appointment = details.appointments!.first as Appointment;
                  final originalObj = appointment.id;
                  
                  if (originalObj is AppEvent) {
                    context.push('/calendar/app-event/${originalObj.id}', extra: originalObj);
                  } else if (originalObj is GroupEvent) {
                    context.push('/group-event/${originalObj.id}', extra: originalObj);
                  }
                }
              },
            );
          }

          final appEvents = data.appEvents;
          final groupEvents = data.groupEvents;

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
            items.addAll(appEvents.map(_buildAppEventCard(canManageApp)));
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'calendar-settings',
            onPressed: _openCalendarSettings,
            child: const Icon(Icons.tune),
          ),
          const SizedBox(height: 16),
          if (canManageApp)
            FloatingActionButton(
              heroTag: 'add-event',
              onPressed: () => _openAppForm(),
              child: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );

  Widget Function(AppEvent) _buildAppEventCard(bool canManageApp) =>
      (AppEvent e) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () => context.push('/calendar/app-event/${e.id}', extra: e),
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
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: CachedNetworkImage(
                          imageUrl: e.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2.0)
                          ),
                          errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.broken_image, size: 24)
                          ),
                      ),
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
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: CachedNetworkImage(
                      imageUrl: e.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.0)
                      ),
                      errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, size: 24)
                      ),
                  ),
              )
              : const Icon(Icons.event, size: 40),
          title: Text(e.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.groupName != null)
                Text(
                  e.groupName!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              Text(
                TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a'),
              ),
            ],
          ),
          isThreeLine: e.groupName != null,
        ),
      );
}

class _CalendarData {
  final List<AppEvent> appEvents;
  final List<GroupEvent> groupEvents;
  _CalendarData({required this.appEvents, required this.groupEvents});
}

class _EventDataSource extends CalendarDataSource {
  _EventDataSource(List<AppEvent> appEvents, List<GroupEvent> groupEvents, ColorScheme colors) {
    final List<Appointment> _appointments = [];

    _appointments.addAll(appEvents.map<Appointment>((e) {
      final start = e.eventDate.toLocal();
      // Use End Time if available, otherwise default to 1 hour
      final end = e.eventEnd != null 
          ? e.eventEnd!.toLocal() 
          : start.add(const Duration(hours: 1));

      return Appointment(
        id: e,
        startTime: start, 
        endTime: end,
        subject: e.title,
        color: colors.primary,
        isAllDay: false,
        location: e.location,
      );
    }));

    _appointments.addAll(groupEvents.map<Appointment>((e) {
      final start = e.eventDate.toLocal();
      // Use End Time if available, otherwise default to 1 hour
      final end = e.eventEnd != null 
          ? e.eventEnd!.toLocal() 
          : start.add(const Duration(hours: 1));

      return Appointment(
        id: e,
        startTime: start,
        endTime: end,
        subject: e.title,
        color: colors.secondary,
        isAllDay: false,
        location: e.location,
        notes: e.groupName, 
      );
    }));

    appointments = _appointments;
  }
}