// filename: lib/features/calendar/calendar_page.dart
//
// Calendar tab, built for ease of use:
//   * Photo header (same look as the landing page) with a "which calendars"
//     button.
//   * One simple switch: Upcoming (default) | Month.
//   * Upcoming: one list grouped by day ("Today", "Tomorrow", …), filter chips
//     for All / Church / My groups, repeating events shown at their next date,
//     past events tucked behind a button.
//   * Month: month / week / schedule as visible chips, plus a Today button.
import 'package:ccf_app/shared/user_roles.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccf_app/core/theme.dart';
import 'package:ccf_app/routes/router_observer.dart';
import 'package:ccf_app/shared/widgets/glass.dart';
import 'package:ccf_app/shared/page_refresh.dart';

import '../../../app_state.dart';
import '../church_event_service.dart';
import '../models/church_event.dart';
import '../../more/models/calendar_settings_modal.dart';

enum _Filter { all, church, groups }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with RouteAware, AutoRefresh<CalendarPage> {
  // Kept from the previous version so a saved choice carries over. New users
  // start on the Upcoming list, which is the easiest view to read.
  static const _viewPrefKey = 'calendar_is_calendar_view';

  late Future<_CalendarData> _calendarFuture;
  late ChurchEventService _eventService;
  bool _svcReady = false;

  bool _isMonthView = false;
  _Filter _filter = _Filter.all;
  bool _showPast = false;
  CalendarView _monthMode = CalendarView.month;
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
    final saved = prefs.getBool(_viewPrefKey);
    if (mounted && saved != null) setState(() => _isMonthView = saved);
  }

  Future<void> _setMonthView(bool value) async {
    setState(() => _isMonthView = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewPrefKey, value);
  }

  Future<_CalendarData> _loadAllEvents() async {
    final appState = context.read<AppState>();

    // 1. Church-wide events
    final publicEvents = await _eventService.fetchPublicEvents(appState.databaseServiceFilter);

    // 2. The user's group events
    List<ChurchEvent> myGroupEvents = [];
    final currentUserId = appState.profile?.id;

    if (currentUserId != null) {
      final fetchedGroupEvents = await _eventService.fetchMyGroupEvents();

      // Only seed on first ever load, not every time the set is empty
      if (!appState.calendarGroupsInitialized) {
        final allGroupIds = fetchedGroupEvents.map((e) => e.groupId).whereType<String>().toSet();
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

  Future<void> _reload() async {
    final next = _loadAllEvents();
    setState(() {
      _calendarFuture = next;
    });
    await next;
  }

  Future<void> _openEventForm([ChurchEvent? existing]) async {
    if (existing != null) {
      await context.push('/manage-app-event/edit?eventId=${existing.id}');
    } else {
      await context.push('/manage-app-event/new');
    }
    if (mounted) _reload();
  }

  void _openCalendarSettings() {
    CalendarSettingsModal.show(context).then((_) {
      if (mounted) _reload();
    });
  }

  void _openEvent(ChurchEvent e) {
    if (e.isGroupOnly) {
      context.push('/group-event/${e.id}');
    } else {
      context.push('/calendar/app-event/${e.id}');
    }
  }

  Future<void> _approve(ChurchEvent e) async {
    await _eventService.approveEvent(e.id);
    if (mounted) _reload();
  }

  Future<void> _delete(ChurchEvent e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('calendar_delete_title'.tr()),
        content: Text('calendar_delete_body'.tr(namedArgs: {'title': e.title})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('calendar_cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text("key_039".tr())),
        ],
      ),
    );
    if (confirmed != true) return;
    await _eventService.deleteEvent(e.id);
    if (mounted) _reload();
  }

  @override
  void didPopNext() => _reload();

  @override
  Future<void> onAutoRefresh() => _reload();

  @override
  Widget build(BuildContext context) {
    final userRole = context.select<AppState, UserRole?>((s) => s.userRole);
    final bool canManageApp = userRole == UserRole.supervisor || userRole == UserRole.owner;

    return Scaffold(
      floatingActionButton: canManageApp
          ? FloatingActionButton.extended(
              heroTag: 'add-event',
              onPressed: () => _openEventForm(),
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add),
              label: Text('calendar_new_event'.tr()),
            )
          : null,
      body: FutureBuilder<_CalendarData>(
        future: _calendarFuture,
        builder: (context, snap) {
          final data = snap.data;
          final entries = data == null ? const <_Entry>[] : _Entry.build(data);
          final upcomingCount = entries.where((x) => !x.isPast).length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: PhotoHeader(
                      height: 120,
                      title: 'calendar_title'.tr(),
                      subtitle: data == null
                          ? null
                          : (upcomingCount == 0
                              ? "key_036".tr()
                              : 'calendar_upcoming_count'.tr(namedArgs: {'count': '$upcomingCount'})),
                      trailing: GlassIconButton(
                        icon: Icons.tune_rounded,
                        tooltip: 'calendar_choose_calendars'.tr(),
                        onPressed: _openCalendarSettings,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.view_agenda_outlined),
                            label: Text('calendar_upcoming'.tr()),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text('calendar_month'.tr()),
                          ),
                        ],
                        selected: {_isMonthView},
                        onSelectionChanged: (s) => _setMonthView(s.first),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody(snap, entries, canManageApp)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<_CalendarData> snap, List<_Entry> entries, bool canManageApp) {
    final colorScheme = Theme.of(context).colorScheme;
    if (snap.connectionState != ConnectionState.done) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }
    if (snap.hasError) {
      return _Message(icon: Icons.cloud_off_outlined, text: 'calendar_load_error'.tr(), onRetry: _reload);
    }
    final data = snap.data!;
    return _isMonthView ? _buildMonth(data) : _buildUpcoming(data, entries, canManageApp);
  }

  // --- MONTH --------------------------------------------------------------

  Widget _buildMonth(_CalendarData data) {
    final colorScheme = Theme.of(context).colorScheme;
    final modes = {
      CalendarView.month: 'calendar_view_month',
      CalendarView.week: 'calendar_view_week',
      CalendarView.schedule: 'calendar_view_schedule',
    };

    // Scrolls, so the month grid keeps a usable size on short windows.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final m in modes.entries)
                      ChoiceChip(
                        label: Text(m.value.tr()),
                        selected: _monthMode == m.key,
                        onSelected: (_) {
                          setState(() => _monthMode = m.key);
                          _calendarController.view = m.key;
                        },
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _calendarController.displayDate = DateTime.now(),
                icon: const Icon(Icons.today_outlined, size: 18),
                label: Text('calendar_today'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _monthMode == CalendarView.month ? 620 : 680,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SfCalendar(
                  controller: _calendarController,
                  view: _monthMode,
                  dataSource: _EventDataSource(data.publicEvents, data.groupEvents, colorScheme),
                  initialSelectedDate: DateTime.now(),
                  backgroundColor: colorScheme.surface.withValues(alpha: 0),
                  todayHighlightColor: kBrandAccent,
                  cellBorderColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  selectionDecoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  appointmentTextStyle: const TextStyle(color: kWhite, fontSize: 12, fontWeight: FontWeight.w600),
                  headerStyle: CalendarHeaderStyle(
                    backgroundColor: colorScheme.surface.withValues(alpha: 0),
                    textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  // SfCalendar draws dark text by default, which vanished on
                  // the dark theme; every text style is set from the theme.
                  viewHeaderStyle: ViewHeaderStyle(
                    backgroundColor: colorScheme.surface.withValues(alpha: 0),
                    dayTextStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    dateTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  timeSlotViewSettings: TimeSlotViewSettings(
                    timeTextStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                  scheduleViewSettings: ScheduleViewSettings(
                    appointmentTextStyle: const TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w600),
                    monthHeaderSettings: MonthHeaderSettings(
                      height: 56,
                      backgroundColor: kBrandPrimary,
                      monthTextStyle: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    weekHeaderSettings: WeekHeaderSettings(
                      weekTextStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    dayHeaderSettings: DayHeaderSettings(
                      dayTextStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700),
                      dateTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  monthViewSettings: MonthViewSettings(
                    appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                    showAgenda: true,
                    agendaViewHeight: 150,
                    agendaItemHeight: 56,
                    monthCellStyle: MonthCellStyle(
                      textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      leadingDatesTextStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45), fontSize: 14),
                      trailingDatesTextStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45), fontSize: 14),
                    ),
                    agendaStyle: AgendaStyle(
                      backgroundColor: colorScheme.surface.withValues(alpha: 0),
                      appointmentTextStyle: const TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w600),
                      dateTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      dayTextStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700),
                    ),
                  ),
                  onTap: (CalendarTapDetails details) {
                    if (details.targetElement == CalendarElement.appointment &&
                        details.appointments?.isNotEmpty == true) {
                      _openEvent(details.appointments!.first.id as ChurchEvent);
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- UPCOMING -----------------------------------------------------------

  Widget _buildUpcoming(_CalendarData data, List<_Entry> all, bool canManageApp) {
    final hasGroupEvents = data.groupEvents.isNotEmpty;
    bool keep(_Entry x) => switch (_filter) {
      _Filter.all => true,
      _Filter.church => x.event.isPublicApp,
      _Filter.groups => x.event.isGroupOnly,
    };

    final upcoming = all.where((x) => !x.isPast && keep(x)).toList();
    final past = all.where((x) => x.isPast && keep(x)).toList().reversed.toList();

    final children = <Widget>[
      if (hasGroupEvents)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final f in _Filter.values)
                ChoiceChip(
                  label: Text(switch (f) {
                    _Filter.all => 'calendar_filter_all'.tr(),
                    _Filter.church => 'calendar_filter_church'.tr(),
                    _Filter.groups => 'calendar_filter_groups'.tr(),
                  }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
        ),
    ];

    if (upcoming.isEmpty) {
      children.add(_Message(icon: Icons.event_available_outlined, text: "key_036".tr()));
    } else {
      children.addAll(_dayGroups(upcoming, canManageApp));
    }

    if (past.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showPast = !_showPast),
              icon: Icon(_showPast ? Icons.expand_less : Icons.history),
              label: Text((_showPast ? 'calendar_hide_past' : 'calendar_show_past').tr()),
            ),
          ),
        ),
      );
      if (_showPast) children.addAll(_dayGroups(past, canManageApp, dimmed: true));
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: children,
      ),
    );
  }

  /// Day header followed by that day's event cards.
  List<Widget> _dayGroups(List<_Entry> entries, bool canManageApp, {bool dimmed = false}) {
    final out = <Widget>[];
    DateTime? currentDay;
    for (final x in entries) {
      final day = DateUtils.dateOnly(x.start);
      if (currentDay != day) {
        currentDay = day;
        out.add(_DayHeader(day: day));
      }
      out.add(
        Opacity(
          opacity: dimmed ? 0.6 : 1,
          child: _EventCard(
            entry: x,
            canManage: canManageApp,
            onTap: () => _openEvent(x.event),
            onApprove: () => _approve(x.event),
            onEdit: () => _openEventForm(x.event),
            onDelete: () => _delete(x.event),
          ),
        ),
      );
    }
    return out;
  }
}

/// One row in the Upcoming list: an event at a specific start time. Repeating
/// events appear once, at their next occurrence.
class _Entry {
  _Entry(this.event, this.start, this.end);

  final ChurchEvent event;
  final DateTime start;
  final DateTime end;

  bool get isPast => end.isBefore(DateTime.now());
  bool get repeats => event.rrule != null && event.rrule!.isNotEmpty;

  static List<_Entry> build(_CalendarData data) {
    final now = DateTime.now();
    final list = <_Entry>[];
    for (final e in [...data.publicEvents, ...data.groupEvents]) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd?.toLocal() ?? start.add(const Duration(hours: 1));
      final duration = end.difference(start);

      if (e.rrule != null && e.rrule!.isNotEmpty && end.isBefore(now)) {
        try {
          final next = SfCalendar.getRecurrenceDateTimeCollection(
            e.rrule!,
            start,
            specificStartDate: DateUtils.dateOnly(now),
            specificEndDate: now.add(const Duration(days: 400)),
          ).where((d) => d.add(duration).isAfter(now));
          if (next.isNotEmpty) {
            list.add(_Entry(e, next.first, next.first.add(duration)));
            continue;
          }
        } catch (_) {
          // Unparseable rule: fall back to the stored date.
        }
      }
      list.add(_Entry(e, start, end));
    }
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = context.locale.toLanguageTag();
    final today = DateUtils.dateOnly(DateTime.now());
    final String label;
    if (day == today) {
      label = 'calendar_today'.tr();
    } else if (day == today.add(const Duration(days: 1))) {
      label = 'calendar_tomorrow'.tr();
    } else {
      label = DateFormat.MMMMEEEEd(locale).format(day);
    }
    final isToday = day == today;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          if (isToday) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: kBrandAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              color: isToday ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.entry,
    required this.canManage,
    required this.onTap,
    required this.onApprove,
    required this.onEdit,
    required this.onDelete,
  });

  final _Entry entry;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final e = entry.event;

    final where = <String>[
      if (e.isGroupOnly && e.groupName != null) e.groupName!,
      if (e.isPublicApp && e.targetAudiences.isNotEmpty)
        e.targetAudiences
            .map((l) => (l == 'english' ? 'calendar_service_english' : 'calendar_service_spanish').tr())
            .join(' & '),
      if (e.location?.isNotEmpty ?? false) e.location!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              children: [
                // Time column
                SizedBox(
                  width: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.jm(locale).format(entry.start),
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        DateFormat.jm(locale).format(entry.end),
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Colored rail: church vs. group
                Container(
                  width: 3,
                  height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: e.isGroupOnly ? kBrandAccent : colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _Thumb(imageUrl: e.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (where.isNotEmpty)
                        Text(
                          where,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      if (entry.repeats || e.isPending) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (entry.repeats)
                              _MiniChip(icon: Icons.event_repeat, label: 'calendar_repeats'.tr()),
                            if (e.isPending)
                              _MiniChip(
                                icon: Icons.hourglass_top_rounded,
                                label: 'calendar_pending'.tr(),
                                emphasized: true,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (canManage && e.isPending)
                  IconButton(
                    tooltip: 'calendar_approve'.tr(),
                    icon: Icon(Icons.check_circle_outline, color: colorScheme.primary),
                    onPressed: onApprove,
                  ),
                if (canManage && e.isPublicApp)
                  PopupMenuButton<String>(
                    onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text("key_038".tr())),
                      PopupMenuItem(value: 'delete', child: Text("key_039".tr())),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label, this.emphasized = false});

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = emphasized ? colorScheme.tertiaryContainer : colorScheme.surfaceContainerHighest;
    final fg = emphasized ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.event_outlined, color: colorScheme.onSurfaceVariant, size: 22),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 44,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHighest),
          errorWidget: (context, url, error) => Container(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(Icons.broken_image_outlined, size: 20, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text('calendar_retry'.tr())),
          ],
        ],
      ),
    );
  }
}

class _CalendarData {
  final List<ChurchEvent> publicEvents;
  final List<ChurchEvent> groupEvents;
  _CalendarData({required this.publicEvents, required this.groupEvents});
}

class _EventDataSource extends CalendarDataSource {
  _EventDataSource(List<ChurchEvent> publicEvents, List<ChurchEvent> groupEvents, ColorScheme colors) {
    final now = DateTime.now();

    // Church events: brand charcoal; group events: brand gold; pending: error
    // color so admins notice. Text on all of them is white (see SfCalendar).
    Color colorFor(ChurchEvent e, Color base) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd?.toLocal() ?? start.add(const Duration(hours: 1));
      final isPast = end.isBefore(now) && (e.rrule == null || e.rrule!.isEmpty);
      final color = e.isPending ? colors.error : base;
      return color.withValues(alpha: isPast ? 0.45 : 0.95);
    }

    Appointment toAppointment(ChurchEvent e, Color base) {
      final start = e.eventDate.toLocal();
      final end = e.eventEnd?.toLocal() ?? start.add(const Duration(hours: 1));
      return Appointment(
        id: e,
        startTime: start,
        endTime: end,
        subject: e.title,
        color: colorFor(e, base),
        isAllDay: false,
        location: e.location,
        notes: e.groupName,
        recurrenceRule: e.rrule,
      );
    }

    appointments = [
      ...publicEvents.map((e) => toAppointment(e, kBrandPrimary)),
      ...groupEvents.map((e) => toAppointment(e, kBrandAccent)),
    ];
  }
}
