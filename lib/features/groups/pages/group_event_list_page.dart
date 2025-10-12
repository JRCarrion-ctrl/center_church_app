// File: lib/features/groups/pages/group_event_list_page.dart
import 'package:flutter/material.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:go_router/go_router.dart';
import 'package:ccf_app/routes/router_observer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';
import '../../calendar/widgets/group_event_form_modal.dart';

class GroupEventListPage extends StatefulWidget {
  final String groupId;

  const GroupEventListPage({super.key, required this.groupId});

  @override
  State<GroupEventListPage> createState() => _GroupEventListPageState();
}

class _GroupEventListPageState extends State<GroupEventListPage> with RouteAware {
  final _attendanceCounts = <String, int>{};
  final _events = <GroupEvent>[];
  bool _loading = true;
  bool _isAdmin = false;

  GraphQLClient? _gql;
  EventService? _service;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _gql ??= GraphProvider.of(context);
    _service ??= EventService(_gql!);

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    if (!_bootstrapped) {
      _bootstrapped = true;
      _initialize();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadEvents();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadEvents(),
      _checkAdminRole(),
    ]);
  }

  Future<void> _checkAdminRole() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    if (userId == null || _gql == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }

    // Prefer group-specific role; fall back to global owner
    const qRole = r'''
      query MyGroupRole($gid: uuid!, $uid: String!) {
        group_memberships(
          where: {
            group_id: { _eq: $gid }
            user_id: { _eq: $uid }
            status: { _eq: "approved" }
          }
          limit: 1
        ) { role }
      }
    ''';

    try {
      final res = await _gql!.query(QueryOptions(
        document: gql(qRole),
        variables: {'gid': widget.groupId, 'uid': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      String? role;
      if (!res.hasException) {
        final rows = (res.data?['group_memberships'] as List?) ?? const [];
        if (rows.isNotEmpty) role = rows.first['role'] as String?;
      }

      final groupAdminRoles = {'admin', 'leader', 'supervisor', 'owner'};
      final isOwnerGlobally = appState.userRole.name == 'owner';

      if (mounted) {
        setState(() {
          _isAdmin = role != null
              ? groupAdminRoles.contains(role)
              : isOwnerGlobally; // fallback
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await _service!.fetchGroupEvents(widget.groupId);
      final counts = <String, int>{};

      for (final event in events) {
        final rsvps = await _service!.fetchGroupEventRSVPs(event.id);
        final total = rsvps.fold<int>(
          0,
          (sum, r) => sum + ((r['attending_count'] ?? 0) as int),
        );
        counts[event.id] = total;
      }

      if (mounted) {
        setState(() {
          _events
            ..clear()
            ..addAll(events);
          _attendanceCounts
            ..clear()
            ..addAll(counts);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFormModal({GroupEvent? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroupEventFormModal(
        existing: existing,
        groupId: widget.groupId,
      ),
    );
    await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_070".tr())),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () => _openFormModal(),
              tooltip: "key_070a".tr(),
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(child: Text("key_071".tr()))
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _events.length,
                    itemBuilder: (_, i) {
                      final e = _events[i];
                      final count = _attendanceCounts[e.id] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () => context.push('/group-event/${e.id}', extra: e),
                          leading: e.imageUrl != null
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
                              if (_isAdmin)
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
                                        await _service?.deleteEvent(e.id);
                                        await _loadEvents();
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
                    },
                  ),
                ),
    );
  }
}
