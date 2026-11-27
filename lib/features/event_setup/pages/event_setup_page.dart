// File: lib/features/event_setup/pages/event_setup_page.dart
//
// Bottom-nav tab for staff (owner, supervisor, admin/security/cleaning
// approvers) and ministry leaders. One scrolling page, like Home and Prayer:
//   create buttons → updates (edits to events) → my submissions →
//   awaiting sign-off → upcoming events → announcements.
// Hasura row filters decide which ministries' rows come back: staff get all,
// leaders only their own ministries.
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';
import '../../../shared/user_roles.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/page_refresh.dart';
import '../event_setup_access.dart';
import '../event_setup_service.dart';
import '../models/event_setup_models.dart';
import '../widgets/hub_tiles.dart';
import '../widgets/new_announcement_form.dart';
import '../widgets/new_event_form.dart';
import '../widgets/pending_request_card.dart';
import '../widgets/setup_card.dart';

/// Filter value for church-wide items (no ministry).
const _churchWide = '__church_wide__';

class EventSetupPage extends StatefulWidget {
  const EventSetupPage({super.key});

  @override
  State<EventSetupPage> createState() => _EventSetupPageState();
}

class _EventSetupPageState extends State<EventSetupPage> with AutoRefresh<EventSetupPage> {
  EventSetupService? _service;
  bool _requested = false;

  List<EventSetupRequest> _requests = const [];
  List<HubAnnouncement> _announcements = const [];
  List<ApprovalPermission> _myPermissions = const [];
  List<EventSetupNotification> _notices = const [];
  bool _loading = true;
  bool _loadFailed = false;
  final Set<String> _busy = {};

  /// null = all ministries; [_churchWide] = no ministry; otherwise a group id.
  String? _filter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= EventSetupService(GraphQLProvider.of(context).value);
  }

  @override
  Future<void> onAutoRefresh() => _reload();

  Future<void> _reload() async {
    final appState = context.read<AppState>();
    final uid = appState.profile?.id;
    if (uid == null || !appState.canOpenEventSetup) return;

    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait<Object>([
        _service!.fetchRequests(),
        _service!.fetchMyPermissions(uid),
        _service!.fetchAnnouncements(),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<EventSetupRequest>;
        _myPermissions = results[1] as List<ApprovalPermission>;
        _announcements = results[2] as List<HubAnnouncement>;
        _loading = false;
      });
      _loadNotices(uid);
    } catch (e) {
      debugPrint('EventSetup: load failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// Loaded on its own so the page still works before the v3 backend
  /// (003_edits_and_notifications.sql) is applied.
  Future<void> _loadNotices(String uid) async {
    try {
      final notices = await _service!.fetchNotifications(uid);
      if (mounted) setState(() => _notices = notices);
    } catch (e) {
      debugPrint('EventSetup: notifications unavailable: $e');
    }
  }

  Future<void> _dismissNotices(List<EventSetupNotification> notices) async {
    final ids = notices.map((n) => n.id).toSet();
    setState(() => _notices = _notices.where((n) => !ids.contains(n.id)).toList());
    try {
      await _service!.markNotificationsRead(ids.toList());
    } catch (e) {
      debugPrint('EventSetup: mark read failed: $e');
    }
  }

  bool _canApprove(UserRole role, SetupDepartment dept, String? groupId) =>
      role == UserRole.owner || _myPermissions.any((p) => p.covers(dept, groupId));

  String _busyKey(String requestId, SetupDepartment dept) => '$requestId:${dept.dbValue}';

  Future<void> _toggle(EventSetupRequest request, SetupDepartment dept, bool approve) async {
    final key = _busyKey(request.id, dept);
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (approve) {
        await _service!.signOff(request.id, dept);
      } else {
        await _service!.revokeSignoff(request.id, dept);
      }
      await _reload();

      final updated = _requests.where((r) => r.id == request.id).firstOrNull;
      if (approve && updated != null && updated.isApproved && !request.isApproved) {
        messenger.showSnackBar(SnackBar(content: Text('event_setup_published'.tr())));
      }
    } catch (e) {
      debugPrint('EventSetup: sign-off failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('event_setup_signoff_error'.tr())));
      await _reload();
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _openForm(Widget Function(EventSetupService service) builder) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => builder(_service!)),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _deleteAnnouncement(HubAnnouncement a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('event_setup_delete_announcement_title'.tr()),
        content: Text('event_setup_delete_announcement_body'.tr(namedArgs: {'title': a.title})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('event_setup_cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('event_setup_delete'.tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service!.deleteAnnouncement(a.id);
      await _reload();
    } catch (e) {
      debugPrint('EventSetup: delete announcement failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('event_setup_perm_error'.tr())));
    }
  }

  bool _matches(String? groupId) {
    if (_filter == null) return true;
    if (_filter == _churchWide) return groupId == null;
    return groupId == _filter;
  }

  /// Ministries that appear in the loaded data, for the filter chips.
  List<MapEntry<String, String>> get _filterOptions {
    final seen = <String, String>{};
    var hasChurchWide = false;
    void add(String? id, String? name) {
      if (id == null) {
        hasChurchWide = true;
      } else {
        seen[id] = name ?? '';
      }
    }

    for (final r in _requests) {
      add(r.groupId, r.groupName);
    }
    for (final a in _announcements) {
      add(a.groupId, a.groupName);
    }
    final list = seen.entries.toList()..sort((x, y) => x.value.toLowerCase().compareTo(y.value.toLowerCase()));
    if (hasChurchWide) list.insert(0, MapEntry(_churchWide, 'event_setup_ministry_none'.tr()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final role = appState.userRole;

    if (!appState.eventSetupAccessLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    // Defense in depth: the router already redirects people without access.
    if (!appState.canOpenEventSetup) {
      return SetupMessage(icon: Icons.lock_outline, text: 'event_setup_no_access'.tr());
    }
    if (!_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }

    final uidForMine = appState.profile?.id;
    final mine = _requests.where((r) => r.createdBy != null && r.createdBy == uidForMine && _matches(r.groupId)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final pending = _requests.where((r) => !r.isApproved && _matches(r.groupId)).toList();
    final upcoming = _requests.where((r) => r.isApproved && _matches(r.groupId)).toList();
    final announcements = _announcements.where((a) => _matches(a.groupId)).toList()
      ..sort((x, y) {
        // Scheduled (soonest first) above posted (newest first).
        if (x.isScheduled != y.isScheduled) return x.isScheduled ? -1 : 1;
        return x.isScheduled ? x.publishAt.compareTo(y.publishAt) : y.publishAt.compareTo(x.publishAt);
      });
    final filterOptions = _filterOptions;
    final uid = appState.profile?.id;
    final firstLoad = _loading && _requests.isEmpty && _announcements.isEmpty;

    return RefreshIndicator(
      onRefresh: _reload,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Same photo + glass look as the landing page.
              PhotoHeader(
                title: 'event_setup_title'.tr(),
                subtitle: (appState.isEventSetupStaff ? 'event_setup_subtitle_staff' : 'event_setup_subtitle_leader').tr(),
                trailing: EventSetupAccess.canManagePermissions(role)
                    ? GlassIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: 'event_setup_permissions_title'.tr(),
                        onPressed: () async {
                          await context.push(EventSetupAccess.permissionsRoute);
                          if (mounted) _reload();
                        },
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              if (appState.canCreateInEventSetup) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ActionTile(
                          emphasized: true,
                          icon: Icons.event_outlined,
                          label: 'event_setup_new_event'.tr(),
                          caption: 'event_setup_new_event_sub'.tr(),
                          onTap: () => _openForm((s) => NewEventPage(service: s)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionTile(
                          icon: Icons.campaign_outlined,
                          label: 'event_setup_new_announcement'.tr(),
                          caption: 'event_setup_new_announcement_sub'.tr(),
                          onTap: () => _openForm((s) => NewAnnouncementPage(service: s)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (filterOptions.length > 1) ...[
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('event_setup_all_ministries'.tr()),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                      ),
                      for (final o in filterOptions)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(o.value),
                            selected: _filter == o.key,
                            onSelected: (_) => setState(() => _filter = o.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (firstLoad)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadFailed && _requests.isEmpty && _announcements.isEmpty)
                SetupMessage(icon: Icons.cloud_off_outlined, text: 'event_setup_load_error'.tr())
              else ...[
                // --- UPDATES: someone edited an event -------------------------
                if (_notices.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(child: _SectionLabel(text: 'event_setup_section_updates'.tr(), count: _notices.length)),
                      if (_notices.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextButton(
                            onPressed: () => _dismissNotices(_notices),
                            child: Text('event_setup_mark_all_read'.tr()),
                          ),
                        ),
                    ],
                  ),
                  for (final n in _notices) ...[
                    EditNoticeTile(notice: n, onDismiss: () => _dismissNotices([n])),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 18),
                ],

                // --- MY SUBMISSIONS ------------------------------------------
                if (mine.isNotEmpty) ...[
                  _SectionLabel(text: 'event_setup_section_mine'.tr(), count: mine.length),
                  for (final r in mine) ...[
                    MySubmissionTile(
                      request: r,
                      onEdit: () => _openForm((s) => NewEventPage(service: s, existing: r)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 20),
                ],

                // --- AWAITING SIGN-OFF ---------------------------------------
                _SectionLabel(text: 'event_setup_section_pending'.tr(), count: pending.length),
                if (pending.isEmpty)
                  _EmptyLine(text: 'event_setup_pending_empty'.tr())
                else
                  for (final r in pending) ...[
                    PendingRequestCard(
                      request: r,
                      canApprove: (dept) => _canApprove(role, dept, r.groupId),
                      isBusy: (dept) => _busy.contains(_busyKey(r.id, dept)),
                      onToggle: _toggle,
                    ),
                    const SizedBox(height: 16),
                  ],
                const SizedBox(height: 16),

                // --- UPCOMING EVENTS -----------------------------------------
                _SectionLabel(text: 'event_setup_section_upcoming'.tr(), count: upcoming.length),
                if (upcoming.isEmpty)
                  _EmptyLine(text: 'event_setup_upcoming_empty'.tr())
                else
                  for (final r in upcoming) ...[
                    ApprovedEventTile(request: r),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 20),

                // --- ANNOUNCEMENTS -------------------------------------------
                _SectionLabel(text: 'event_setup_section_announcements'.tr(), count: announcements.length),
                if (announcements.isEmpty)
                  _EmptyLine(text: 'event_setup_announcements_empty'.tr())
                else
                  for (final a in announcements) ...[
                    AnnouncementTile(
                      announcement: a,
                      onDelete: (EventSetupAccess.isAdmin(role) || a.createdBy == uid)
                          ? () => _deleteAnnouncement(a)
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Badge(
              label: Text('$count'),
              backgroundColor: colorScheme.secondaryContainer,
              textColor: colorScheme.onSecondaryContainer,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(text, style: TextStyle(color: colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
