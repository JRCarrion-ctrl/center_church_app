// File: lib/features/groups/widgets/group_calendar_tab.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../calendar/models/group_event.dart';
import '../../calendar/event_service.dart';

class GroupCalendarTab extends StatelessWidget {
  final String groupId;

  const GroupCalendarTab({super.key, required this.groupId});

  Future<List<GroupEvent>> _loadEvents() {
    return EventService().fetchGroupEvents(groupId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupEvent>>(
      future: _loadEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return const Center(child: Text('No upcoming events.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                onTap: () {
                  context.push('/event/${event.id}');
                },
                leading: event.imageUrl != null
                    ? Image.network(event.imageUrl!, width: 60, fit: BoxFit.cover)
                    : const Icon(Icons.event, size: 40),
                title: Text(event.title),
                subtitle: Text(
                  _formatDate(event.eventDate),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} @ ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
