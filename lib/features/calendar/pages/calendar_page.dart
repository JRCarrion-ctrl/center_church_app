// File: lib/features/calendar/pages/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../event_service.dart';
import '../models/group_event.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late Future<List<GroupEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = EventService().fetchUpcomingEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<GroupEvent>>(
        future: _eventsFuture,
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
                  onTap: () => context.push('/event/${event.id}'),
                  leading: event.imageUrl != null
                      ? Image.network(event.imageUrl!, width: 60, fit: BoxFit.cover)
                      : const Icon(Icons.event, size: 40),
                  title: Text(event.title),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(event.eventDate),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
