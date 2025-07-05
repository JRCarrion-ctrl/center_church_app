import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../event_service.dart';
import '../models/app_event.dart';

class AppEventDetailsPage extends StatefulWidget {
  final AppEvent event;

  const AppEventDetailsPage({super.key, required this.event});

  @override
  State<AppEventDetailsPage> createState() => _AppEventDetailsPageState();
}

class _AppEventDetailsPageState extends State<AppEventDetailsPage> {
  final _eventService = EventService();
  int _attendingCount = 1;
  bool _saving = false;
  bool _isSupervisor = false;
  List<Map<String, dynamic>> _rsvps = [];

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadRSVPs();
  }

  Future<void> _checkRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    if (mounted) {
      setState(() {
        _isSupervisor = profile['role'] == 'leader' || profile['role'] == 'supervisor' || profile['role'] == 'owner';
      });
    }
  }

  Future<void> _loadRSVPs() async {
    try {
      final data = await _eventService.fetchAppEventRSVPs(widget.event.id);
      if (mounted) setState(() => _rsvps = data);
    } catch (_) {}
  }

  Future<void> _submitRSVP() async {
    setState(() => _saving = true);
    try {
      await _eventService.rsvpAppEvent(
        appEventId: widget.event.id,
        count: _attendingCount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RSVP saved')),
        );
        _loadRSVPs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (e.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(e.imageUrl!, height: 200, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Text(
            e.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(DateFormat('EEEE, MMM d, yyyy • h:mm a').format(e.eventDate)),
          const SizedBox(height: 16),
          if (e.description?.isNotEmpty ?? false)
            Text(e.description ?? '', style: Theme.of(context).textTheme.bodyLarge),
          const Divider(height: 32),
          Text('Are you attending?', style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              const Text('Count:'),
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
                child: _saving ? const CircularProgressIndicator() : const Text('Submit RSVP'),
              )
            ],
          ),
          const Divider(height: 32),
          if (_isSupervisor && _rsvps.isNotEmpty) ...[
            Text('RSVP Summary:', style: Theme.of(context).textTheme.titleMedium),
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
