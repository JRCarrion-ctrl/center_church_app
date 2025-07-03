// File: lib/features/groups/pages/manage_events_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../calendar/models/group_event.dart';
import '../../calendar/event_service.dart';
import '../widgets/event_form_modal.dart';

class ManageGroupEventsPage extends StatefulWidget {
  final String groupId;

  const ManageGroupEventsPage({super.key, required this.groupId});

  @override
  State<ManageGroupEventsPage> createState() => _ManageGroupEventsPageState();
}

class _ManageGroupEventsPageState extends State<ManageGroupEventsPage> {
  final supabase = Supabase.instance.client;
  List<GroupEvent> _events = [];
  Map<String, List<Map<String, dynamic>>> _rsvps = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);

    try {
      final response = await supabase
          .from('group_events')
          .select()
          .eq('group_id', widget.groupId)
          .order('event_date', ascending: false);

      final events = (response as List)
          .map((e) => GroupEvent.fromMap(e))
          .toList();

      final rsvpMap = <String, List<Map<String, dynamic>>>{};

      for (final event in events) {
        final rsvps = await EventService().fetchRSVPs(event.id);
        rsvpMap[event.id] = rsvps;
      }

      if (mounted) {
        setState(() {
          _events = events;
          _rsvps = rsvpMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load events: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([GroupEvent? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EventFormModal(
        groupId: widget.groupId,
        existing: existing,
      ),
    );
    _loadEvents();
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    await EventService().deleteEvent(eventId);
    _loadEvents();
  }

  Future<void> _showRSVPs(String eventId) async {
    final rsvps = _rsvps[eventId] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendees'),
        content: SizedBox(
          width: double.maxFinite,
          child: rsvps.isEmpty
              ? const Text('No RSVPs yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rsvps.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final rsvp = rsvps[index];
                    final profile = rsvp['profiles'] ?? {};
                    final name = profile['display_name'] ?? 'Unnamed';
                    final email = profile['email'] ?? 'No email';
                    final count = rsvp['attending_count'] ?? 1;

                    return ListTile(
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: Text('x$count'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('No events yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final totalAttending = _rsvps[event.id]?.fold<int>(
                          0,
                          (sum, item) => sum + (item['attending_count'] as int? ?? 0),
                        ) ??
                        0;

                    return Card(
                      child: ListTile(
                        title: Text(event.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy • h:mm a').format(event.eventDate),
                            ),
                            if (totalAttending > 0)
                              Text('RSVPs: $totalAttending attending'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _openForm(event);
                                break;
                              case 'rsvps':
                                _showRSVPs(event.id);
                                break;
                              case 'delete':
                                _deleteEvent(event.id);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'rsvps', child: Text('View RSVPs')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
