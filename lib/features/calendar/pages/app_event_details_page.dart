// filename: app_event_details_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';
import '../event_service.dart';
import '../models/app_event.dart';

class AppEventDetailsPage extends StatefulWidget {
  final AppEvent event;

  const AppEventDetailsPage({super.key, required this.event});

  @override
  State<AppEventDetailsPage> createState() => _AppEventDetailsPageState();
}

class _AppEventDetailsPageState extends State<AppEventDetailsPage> {
  late EventService _eventService;
  bool _svcReady = false;

  int _attendingCount = 1;
  bool _saving = false;
  List<Map<String, dynamic>> _rsvps = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_svcReady) {
      final client = GraphQLProvider.of(context).value;
      final userId = context.read<AppState>().profile?.id;
      _eventService = EventService(client, currentUserId: userId);
      _svcReady = true;

      _loadRSVPs();
    }
  }

  Future<void> _loadRSVPs() async {
    if (!_svcReady) return;
    try {
      final data = await _eventService.fetchAppEventRSVPs(widget.event.id);
      if (mounted) {
        final currentUserId = context.read<AppState>().profile?.id;

        // Safely find the current user's RSVP entry
        final existingRsvp = data.firstWhere(
          (r) => r['user_id'] == currentUserId,
        );

        setState(() {
          _rsvps = data;
          // FIX: Initialize _attendingCount with the existing value, or default to 1.
          // This prevents accidentally overwriting a higher count with 1.
          _attendingCount = existingRsvp['attending_count'] as int? ?? 1;
        });
      }
    } catch (_) {
      // no-op
    }
  }

  Future<void> _submitRSVP() async {
    if (!_svcReady) return;
    setState(() => _saving = true);
    try {
      await _eventService.rsvpAppEvent(
        appEventId: widget.event.id,
        count: _attendingCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_027".tr())),
      );
      _loadRSVPs();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_028".tr())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeRSVP() async {
    if (!_svcReady) return;
    setState(() => _saving = true);
    try {
      await _eventService.removeAppEventRSVP(widget.event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_029".tr())),
      );
      _loadRSVPs();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_030".tr())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void addEventToCalendar(AppEvent event) {
    final Event calendarEvent = Event(
      title: event.title,
      description: event.description,
      startDate: event.eventDate,
      endDate: event.eventDate.add(const Duration(hours: 1)),
      location: event.location ?? '5115 Pegasus Ct. Frederick, MD 21704 United States',
    );
    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final currentUserId = context.select<AppState, String?>((s) => s.profile?.id);
    final hasRSVP = currentUserId != null && _rsvps.any((r) => r['user_id'] == currentUserId);

    final userRole = context.select<AppState, UserRole?>((s) => s.userRole);
    final bool isSupervisor = userRole == UserRole.supervisor || userRole == UserRole.owner || userRole == UserRole.leader;


    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (e.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                e.imageUrl!,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(e.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            TimeService.formatUtcToLocal(
              e.eventDate,
              pattern: 'EEEE, MMM d, yyyy • h:mm a',
            ),
          ),
          const SizedBox(height: 6),
          if ((e.description ?? '').isNotEmpty)
            Text(e.description!, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 6),
          if ((e.location ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Location: ${e.location}', style: Theme.of(context).textTheme.bodyMedium),
            ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: () => addEventToCalendar(e),
            icon: const Icon(Icons.event),
            label: Text("key_031".tr()),
          ),
          const Divider(height: 32),
          Text("key_031a".tr(), style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              Text("key_032".tr()),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _attendingCount,
                onChanged: (val) => setState(() => _attendingCount = val!),
                items: List.generate(10, (i) => i + 1)
                    .map((i) => DropdownMenuItem(value: i, child: Text(i.toString())))
                    .toList(),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _submitRSVP,
                child: _saving ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                ) : Text(hasRSVP ? "key_033".tr() : "key_033".tr()),
              ),
              if (hasRSVP)
                TextButton(
                  onPressed: _saving ? null : _removeRSVP,
                  child: Text("key_033a".tr(), style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const Divider(height: 32),
          if (isSupervisor && _rsvps.isNotEmpty) ...[
            Text("key_033b".tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._rsvps.map((rsvp) {
              final profile = rsvp['profiles'] ?? {};
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(profile['display_name'] ?? 'Unknown'),
                subtitle: Text(profile['email'] ?? ''),
                trailing: Text('x${rsvp['attending_count']}'),
              );
            }),
          ]
        ],
      ),
    );
  }
}