import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';

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

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
                              ? Image.network(e.imageUrl!, width: 60, fit: BoxFit.cover)
                              : const Icon(Icons.event, size: 40),
                          title: Text(e.title),
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