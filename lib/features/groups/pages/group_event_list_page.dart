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
      if (mounted) setState(() => _events = events);
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (_, i) {
                    final e = _events[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => context.push('/group-event/${e.id}', extra: e),
                        leading: e.imageUrl != null
                            ? Image.network(e.imageUrl!, width: 60, fit: BoxFit.cover)
                            : const Icon(Icons.event, size: 40),
                        title: Text(e.title),
                        subtitle: Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(e.eventDate),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
