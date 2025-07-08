import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 Add this

import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';
import '../../calendar/widgets/group_event_form_modal.dart';

class GroupEventListPage extends StatefulWidget {
  final String groupId;

  const GroupEventListPage({super.key, required this.groupId});

  @override
  State<GroupEventListPage> createState() => _GroupEventListPageState();
}

class _GroupEventListPageState extends State<GroupEventListPage> {
  final EventService _service = EventService();
  List<GroupEvent> _events = [];
  Map<String, int> _attendanceCounts = {}; // Event ID -> total attending count
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _checkAdminRole();
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
        _isAdmin = role == 'leader' || role == 'supervisor' || role == 'owner';
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await _service.fetchGroupEvents(widget.groupId);
      final counts = <String, int>{};

      for (final event in events) {
        final rsvps = await _service.fetchRSVPS(event.id);
        final total = rsvps.fold<int>(
          0,
          (sum, r) => sum + ((r['attending_count'] ?? 0) as int),
        );

        counts[event.id] = total;
      }

      if (mounted) {
        setState(() {
          _events = events;
          _attendanceCounts = counts;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading events: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Events')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => GroupEventFormModal(
                    existing: null, // creating new event
                    groupId: widget.groupId, // pass the groupId to the modal
                  ),
                );
                setState(() => _loadEvents());
              },
              tooltip: 'Add Group Event',
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('No upcoming events.'))
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
                                  gaplessPlayback: true, // prevents flicker
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.event, size: 40),
                          title: Row(
                            children: [
                              Expanded(child: Text(e.title)),
                              if (_isAdmin)
                                PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) => GroupEventFormModal(existing: e),
                                      );
                                      setState(() => _loadEvents());
                                    } else if (action == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Event'),
                                          content: const Text('Are you sure you want to delete this event?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                               child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _service.deleteEvent(e.id);
                                        setState(() => _loadEvents());
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${DateFormat('MMM d, yyyy • h:mm a').format(e.eventDate)}\n$count attending',
                          ),
                        ),
                      );

                    },
                  ),
                ),
    );
  }
}
