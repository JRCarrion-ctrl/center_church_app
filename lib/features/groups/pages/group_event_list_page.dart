import 'package:flutter/material.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/routes/router_observer.dart';
import 'package:easy_localization/easy_localization.dart';

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
  final _service = EventService();
  final _attendanceCounts = <String, int>{};
  final _events = <GroupEvent>[];
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initialize();
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
    _loadEvents();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadEvents(),
      _checkAdminRole(),
    ]);
  }

  Future<void> _checkAdminRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

    final role = profile['role'];
    if (mounted) {
      setState(() {
        _isAdmin = ['leader', 'supervisor', 'owner'].contains(role);
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await _service.fetchGroupEvents(widget.groupId);
      final counts = <String, int>{};

      for (final event in events) {
        final rsvps = await _service.fetchGroupEventRSVPs(event.id);
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
                                        await _service.deleteEvent(e.id);
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
