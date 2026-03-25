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
import '../church_event_service.dart';
import '../models/church_event.dart';
import '../../more/models/calendar_settings_modal.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with RouteAware {
  late Future<_CalendarData> _calendarFuture;
  String _refreshKey = UniqueKey().toString();
  late ChurchEventService _eventService;
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
      _eventService = ChurchEventService(client, currentUserId: userId);
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
    setState(() => _isCalendarView = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calendar_is_calendar_view', newValue);
  }

  Future<_CalendarData> _loadAllEvents() async {
    final appState = context.read<AppState>();
    
    // 1. Fetch Public App Events
    final publicEvents = await _eventService.fetchPublicEvents(appState.databaseServiceFilter);

    // 2. Fetch User's Group Events
    List<ChurchEvent> myGroupEvents = [];
    final currentUserId = appState.profile?.id;

    if (currentUserId != null) {
      final fetchedGroupEvents = await _eventService.fetchMyGroupEvents();

      // Only seed on first ever load, not every time the set is empty
      if (!appState.calendarGroupsInitialized) {
        final allGroupIds = fetchedGroupEvents
            .map((e) => e.groupId)
            .whereType<String>()
            .toSet();
        appState.setVisibleCalendarGroupIds(allGroupIds.toList());
        appState.markCalendarGroupsInitialized();
      }

      final visibleGroupIds = appState.visibleCalendarGroupIds.toSet();
      myGroupEvents = fetchedGroupEvents
          .where((e) => e.groupId != null && visibleGroupIds.contains(e.groupId))
          .toList();
    }
    
    return _CalendarData(publicEvents: publicEvents, groupEvents: myGroupEvents);
  }

  Future<void> _openEventForm([ChurchEvent? existing]) async {
    if (existing != null) {
      await context.push('/manage-app-event/edit?eventId=${existing.id}');
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
      extendBodyBehindAppBar: true, 
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isCalendarView ? "key_034".tr() : "key_list_view".tr(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ), 
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_month),
            onPressed: _toggleView,
          ),
          if (_isCalendarView) ...[
            IconButton(icon: const Icon(Icons.today), onPressed: () => _calendarController.displayDate = DateTime.now()),
            PopupMenuButton<CalendarView>(
              icon: const Icon(Icons.view_agenda),
              onSelected: (view) => _calendarController.view = view,
              itemBuilder: (context) => const [
                PopupMenuItem(value: CalendarView.month, child: Text("Month")),
                PopupMenuItem(value: CalendarView.week, child: Text("Week")),
                PopupMenuItem(value: CalendarView.schedule, child: Text("Schedule")),
              ],
            ),
          ]
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/landing_v2_blurred_2.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75))),
          SafeArea(
            child: FutureBuilder<_CalendarData>(
              future: _calendarFuture,
              key: Key(_refreshKey),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                if (snap.hasError) return Center(child: Text("key_035".tr()));

                final data = snap.data!;
                
                // --- CALENDAR VIEW ---
                if (_isCalendarView) {
                  final dataSource = _EventDataSource(data.publicEvents, data.groupEvents, colorScheme);
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
                          backgroundColor: Colors.transparent,
                          headerStyle: CalendarHeaderStyle(textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                          monthViewSettings: const MonthViewSettings(appointmentDisplayMode: MonthAppointmentDisplayMode.appointment, showAgenda: true, agendaStyle: AgendaStyle(backgroundColor: Colors.transparent)),
                          onTap: (CalendarTapDetails details) {
                            if (details.targetElement == CalendarElement.appointment && details.appointments?.isNotEmpty == true) {
                              final ChurchEvent event = details.appointments!.first.id;
                              
                              // 🚀 SCRUBBED: Removed 'extra' from the routing
                              if (event.isGroupOnly) {
                                context.push('/group-event/${event.id}');
                              } else {
                                context.push('/calendar/app-event/${event.id}');
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  );
                }

                // --- LIST VIEW ---
                final now = DateTime.now();

                // Partition Events
                final upcomingPublic = data.publicEvents.where((e) => (e.eventEnd ?? e.eventDate.add(const Duration(hours: 1))).toLocal().isAfter(now)).toList();
                final pastPublic = data.publicEvents.where((e) => (e.eventEnd ?? e.eventDate.add(const Duration(hours: 1))).toLocal().isBefore(now)).toList().reversed.toList();

                final upcomingGroup = data.groupEvents.where((e) => (e.eventEnd ?? e.eventDate.add(const Duration(hours: 1))).toLocal().isAfter(now)).toList();
                final pastGroup = data.groupEvents.where((e) => (e.eventEnd ?? e.eventDate.add(const Duration(hours: 1))).toLocal().isBefore(now)).toList().reversed.toList();

                if (data.publicEvents.isEmpty && data.groupEvents.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() { _calendarFuture = _loadAllEvents(); _refreshKey = UniqueKey().toString(); });
                      await _calendarFuture;
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 200),
                        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.event_busy, size: 48, color: colorScheme.outline),
                          const SizedBox(height: 16),
                          Text("key_036".tr(), style: theme.textTheme.titleMedium),
                        ])),
                      ],
                    ),
                  );
                }

                final List<Widget> items = [];
                
                if (upcomingPublic.isNotEmpty) {
                  items.add(_sectionHeader("key_036a".tr(), colorScheme));
                  items.addAll(upcomingPublic.map((e) => _buildUnifiedEventCard(e, canManageApp)));
                }
                if (upcomingGroup.isNotEmpty) {
                  items.add(_sectionHeader("key_036b".tr(), colorScheme));
                  items.addAll(upcomingGroup.map((e) => _buildUnifiedEventCard(e, canManageApp)));
                }

                if (pastPublic.isNotEmpty || pastGroup.isNotEmpty) {
                  items.add(const SizedBox(height: 16));
                  final List<Widget> pastWidgets = [];
                  if (pastPublic.isNotEmpty) {
                    pastWidgets.add(_sectionHeader("Past Church Events".tr(), colorScheme));
                    pastWidgets.addAll(pastPublic.map((e) => _buildUnifiedEventCard(e, canManageApp)));
                  }
                  if (pastGroup.isNotEmpty) {
                    pastWidgets.add(_sectionHeader("Past Group Events".tr(), colorScheme));
                    pastWidgets.addAll(pastGroup.map((e) => _buildUnifiedEventCard(e, canManageApp)));
                  }

                  items.add(
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        title: Text("View Past Events".tr(), style: TextStyle(color: colorScheme.outline, fontWeight: FontWeight.bold)),
                        collapsedIconColor: colorScheme.outline,
                        iconColor: colorScheme.primary,
                        children: pastWidgets,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() { _calendarFuture = _loadAllEvents(); _refreshKey = UniqueKey().toString(); });
                    await _calendarFuture;
                  },
                  color: colorScheme.primary,
                  child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: items),
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
              onPressed: () => _openEventForm(),
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
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: colorScheme.primary)),
      );

  Widget _buildUnifiedEventCard(ChurchEvent e, bool isGlobalAdmin) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SleekCard(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () {
          if (e.isGroupOnly) {
            context.push('/group-event/${e.id}');
          } else {
            context.push('/calendar/app-event/${e.id}');
          }
        },
        // --- UPDATED TRAILING SECTION ---
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Approval Button (Only for Global Admins on Pending events)
            if (isGlobalAdmin && e.status == 'pending_approval')
              IconButton(
                tooltip: "Approve Event",
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () async {
                  // 1. Do the async work FIRST (outside setState)
                  await _eventService.approveEvent(e.id);
                  
                  // 2. Prepare the new data
                  final newFuture = _loadAllEvents();

                  // 3. Update the state synchronously
                  if (mounted) {
                    setState(() {
                      _calendarFuture = newFuture;
                      _refreshKey = UniqueKey().toString();
                    });
                  }
                },
              ),
            
            // 2. Existing Popup Menu or Chevron
            if (isGlobalAdmin && e.isPublicApp)
              PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'edit') {
                    await _openEventForm(e);
                  } else if (action == 'delete') {
                    // 1. Perform the async work
                    await _eventService.deleteEvent(e.id);
                    
                    // 2. Refresh the UI
                    final newFuture = _loadAllEvents();
                    setState(() {
                      _calendarFuture = newFuture;
                    });
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text("key_038".tr())),
                  PopupMenuItem(value: 'delete', child: Text("key_039".tr())),
                ],
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        leading: _buildEventThumbnail(e.imageUrl, colorScheme),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold))),
              // --- ADD PENDING BADGE HERE ---
              if (e.status == 'pending_approval')
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text('PENDING', style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (e.isGroupOnly && e.groupName != null)
              Text(e.groupName!, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.primary)),
            
            if (e.isPublicApp && e.targetAudiences.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  e.targetAudiences.map((l) => l == 'english' ? 'TCCF' : 'Centro').join(' & '),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.tertiary),
                ),
              ),
            
            Row(
              children: [
                Text(TimeService.formatUtcToLocal(e.eventDate, pattern: 'MMM d, yyyy • h:mm a')),
                if (e.rrule != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.event_repeat, size: 14, color: colorScheme.primary),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventThumbnail(String? imageUrl, ColorScheme colorScheme) {
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 50, height: 50,
          child: CachedNetworkImage(
            imageUrl: imageUrl, fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHighest, child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0))),
            errorWidget: (context, url, error) => Container(color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image, size: 24)),
          ),
        ),
      );
    }
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.event, color: colorScheme.primary),
    );
  }
}

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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _CalendarData {
  final List<ChurchEvent> publicEvents;
  final List<ChurchEvent> groupEvents;
  _CalendarData({required this.publicEvents, required this.groupEvents});
}

class _EventDataSource extends CalendarDataSource {
  _EventDataSource(
    List<ChurchEvent> publicEvents, 
    List<ChurchEvent> groupEvents, 
    ColorScheme colors
  ) {
    final List<Appointment> mappedAppointments = [];
    final now = DateTime.now();

    // Helper to determine appointment color
    Color getAppointmentColor(ChurchEvent e, Color baseColor) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd != null 
          ? e.eventEnd!.toLocal() 
          : start.add(const Duration(hours: 1));
      final isPast = end.isBefore(now);
      
      // 1. If Pending: Use a distinct orange to alert the Admin
      if (e.status == 'pending_approval') {
        return Colors.orange.withValues(alpha: isPast ? 0.5 : 0.9);
      }

      // 2. If Approved: Use the standard category colors
      return baseColor.withValues(alpha: isPast ? 0.4 : 0.8);
    }

    // Process Public Events
    mappedAppointments.addAll(publicEvents.map<Appointment>((e) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd != null ? e.eventEnd!.toLocal() : start.add(const Duration(hours: 1));
      final baseColor = e.isBilingual ? colors.tertiary : const Color.fromARGB(255, 34, 28, 217);

      return Appointment(
        id: e, 
        startTime: start, 
        endTime: end, 
        subject: e.status == 'pending_approval' ? "⚠️ ${e.title}" : e.title,
        color: getAppointmentColor(e, baseColor),
        isAllDay: false, 
        location: e.location, 
        recurrenceRule: e.rrule, 
      );
    }));

    // Process Group Events
    mappedAppointments.addAll(groupEvents.map<Appointment>((e) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd != null ? e.eventEnd!.toLocal() : start.add(const Duration(hours: 1));

      return Appointment(
        id: e, 
        startTime: start, 
        endTime: end, 
        subject: e.status == 'pending_approval' ? "⏳ ${e.title}" : e.title,
        color: getAppointmentColor(e, colors.secondary),
        isAllDay: false, 
        location: e.location, 
        notes: e.groupName, 
        recurrenceRule: e.rrule, 
      );
    }));

    appointments = mappedAppointments;
  }
}