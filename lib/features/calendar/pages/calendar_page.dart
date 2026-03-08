// filename: lib/features/calendar/calendar_page.dart
import 'package:ccf_app/shared/user_roles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/routes/router_observer.dart';

import '../../../app_state.dart';
import '../event_service.dart';
import '../models/group_event.dart';
import '../models/app_event.dart';
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

  bool _isCalendarView = true;

  final CalendarController _calendarController = CalendarController();

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isCalendarView = prefs.getBool('calendar_is_calendar_view') ?? true;
      });
    }
  }

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
    if (existing != null) {
      await context.push('/manage-app-event/edit', extra: existing);
    } else {
      await context.push('/manage-app-event/new');
    }
  
    if (mounted) {
      setState(() {
        _calendarFuture = _loadAllEvents();
        _refreshKey = UniqueKey().toString();
      });
    }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // ✨ Extend body behind AppBar for seamless background
      extendBodyBehindAppBar: true, 
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // ✨ Transparent AppBar to let the blur shine through
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isCalendarView ? "key_034".tr() : "key_list_view".tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ), 
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_month),
            tooltip: _isCalendarView ? "Switch to List" : "Switch to Calendar",
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
      body: Stack(
        children: [
          // 1. Atmospheric Background
          Positioned.fill(
            child: Image.asset('assets/landing_v2_blurred_2.png', fit: BoxFit.cover),
          ),
          // 2. Translucent Overlay
          Positioned.fill(
            child: Container(
              color: isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75),
            ),
          ),
          // 3. Main Content Wrapper
          SafeArea(
            child: FutureBuilder<_CalendarData>(
              future: _calendarFuture,
              key: Key(_refreshKey),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                if (snap.hasError) {
                  return Center(child: Text("key_035".tr()));
                }

                final data = snap.data!;
                
                // --- CALENDAR VIEW ---
                if (_isCalendarView) {
                  final dataSource = _EventDataSource(data.appEvents, data.groupEvents, colorScheme);
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _SleekCard(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SfCalendar(
                          controller: _calendarController,
                          view: CalendarView.month,
                          dataSource: dataSource,
                          initialSelectedDate: DateTime.now(),
                          backgroundColor: Colors.transparent, // Make inner calendar transparent
                          headerStyle: CalendarHeaderStyle(
                            textStyle: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )
                          ),
                          monthViewSettings: const MonthViewSettings(
                            appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                            showAgenda: true,
                            agendaStyle: AgendaStyle(backgroundColor: Colors.transparent),
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
                        ),
                      ),
                    ),
                  );
                }

                // --- LIST VIEW ---
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
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 48, color: colorScheme.outline),
                              const SizedBox(height: 16),
                              Text("key_036".tr(), style: theme.textTheme.titleMedium),
                            ],
                          )
                        ),
                      ],
                    ),
                  );
                }

                final List<Widget> items = [];
                if (appEvents.isNotEmpty) {
                  items.add(_sectionHeader("key_036a".tr(), colorScheme));
                  items.addAll(appEvents.map(_buildAppEventCard(canManageApp)));
                }
                if (groupEvents.isNotEmpty) {
                  items.add(_sectionHeader("key_036b".tr(), colorScheme));
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
                  color: colorScheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: items,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'calendar-settings',
            onPressed: _openCalendarSettings,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            shape: const StadiumBorder(),
            elevation: 4,
            child: const Icon(Icons.tune),
          ),
          const SizedBox(height: 16),
          if (canManageApp)
            FloatingActionButton(
              heroTag: 'add-event',
              onPressed: () => _openAppForm(),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: const StadiumBorder(),
              elevation: 4,
              child: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, ColorScheme colorScheme) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 12, left: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w800, 
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
      );

  Widget Function(AppEvent) _buildAppEventCard(bool canManageApp) =>
      (AppEvent e) => _SleekCard(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
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
                  : const Icon(Icons.chevron_right, color: Colors.grey),
              leading: _buildEventThumbnail(e.imageUrl, Theme.of(context).colorScheme),
              title: Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  e.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              subtitle: Text(
                TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a'),
              ),
            ),
          );

  Widget _buildGroupEventCard(GroupEvent e) => _SleekCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          onTap: () => context.push('/group-event/${e.id}', extra: e),
          leading: _buildEventThumbnail(e.imageUrl, Theme.of(context).colorScheme),
          title: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              e.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.groupName != null)
                Text(
                  e.groupName!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a'),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          isThreeLine: e.groupName != null,
        ),
      );

  Widget _buildEventThumbnail(String? imageUrl, ColorScheme colorScheme) {
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 50,
          height: 50,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
            ),
            errorWidget: (context, url, error) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image, size: 24),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.event, color: colorScheme.primary),
    );
  }
}

// ✨ Universal Sleek Card for the Calendar Items
class _SleekCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _SleekCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CalendarData {
  final List<AppEvent> appEvents;
  final List<GroupEvent> groupEvents;
  _CalendarData({required this.appEvents, required this.groupEvents});
}

class _EventDataSource extends CalendarDataSource {
  _EventDataSource(List<AppEvent> appEvents, List<GroupEvent> groupEvents, ColorScheme colors) {
    // ignore: no_leading_underscores_for_local_identifiers
    final List<Appointment> _appointments = [];

    _appointments.addAll(appEvents.map<Appointment>((e) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd != null ? e.eventEnd!.toLocal() : start.add(const Duration(hours: 1));

      return Appointment(
        id: e,
        startTime: start, 
        endTime: end,
        subject: e.title,
        color: Color.fromARGB(255, 34, 28, 217).withValues(alpha: 0.8),
        isAllDay: false,
        location: e.location,
      );
    }));

    _appointments.addAll(groupEvents.map<Appointment>((e) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd != null ? e.eventEnd!.toLocal() : start.add(const Duration(hours: 1));

      return Appointment(
        id: e,
        startTime: start,
        endTime: end,
        subject: e.title,
        color: colors.secondary.withValues(alpha: 0.8),
        isAllDay: false,
        location: e.location,
        notes: e.groupName, 
      );
    }));

    appointments = _appointments;
  }
}