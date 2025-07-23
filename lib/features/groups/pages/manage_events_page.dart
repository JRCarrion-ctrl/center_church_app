import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:ccf_app/core/time_service.dart';
import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';

class GroupEventDetailsPage extends StatefulWidget {
  final GroupEvent event;

  const GroupEventDetailsPage({super.key, required this.event});

  @override
  State<GroupEventDetailsPage> createState() => _GroupEventDetailsPageState();
}

class _GroupEventDetailsPageState extends State<GroupEventDetailsPage> {
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
        _isSupervisor = ['leader', 'supervisor', 'owner'].contains(profile['role']);
      });
    }
  }

  Future<void> _removeRSVP() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('event_attendance')
          .delete()
          .match({
            'event_id': widget.event.id,
            'user_id': Supabase.instance.client.auth.currentUser!.id,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RSVP removed')),
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

  Future<void> _loadRSVPs() async {
    try {
      final data = await _eventService.fetchGroupEventRSVPs(widget.event.id);
      if (mounted) setState(() => _rsvps = data);
    } catch (_) {}
  }

  Future<void> _submitRSVP() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('event_attendance').upsert({
        'event_id': widget.event.id,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'attending_count': _attendingCount,
      }, onConflict: 'event_id, user_id');

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

  void addEventToCalendar(GroupEvent event) {
    final Event calendarEvent = Event(
      title: event.title,
      description: event.description,
      startDate: event.eventDate,
      endDate: event.eventDate.add(const Duration(hours: 1)),
      location: event.location ?? 'Center Church',
    );

    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final hasRSVP = _rsvps.any((r) => r['user_id'] == currentUserId);
    final e = widget.event;

    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (e.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: e.imageUrl!,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 100),
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
          if (e.description?.isNotEmpty == true)
            Text(e.description!, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 6),
          if (e.location?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Location: ${e.location}', style: Theme.of(context).textTheme.bodyMedium),
            ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: () => addEventToCalendar(e),
            icon: const Icon(Icons.event),
            label: const Text('Add to Calendar'),
          ),
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
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Submit RSVP'),
              ),
              if (hasRSVP)
                TextButton(
                  onPressed: _saving ? null : _removeRSVP,
                  child: const Text(
                    'Remove RSVP',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          const Divider(height: 32),
          if (_isSupervisor && _rsvps.isNotEmpty) ...[
            Text('RSVP Summary:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._rsvps.map((rsvp) {
              final profile = rsvp['profiles'] ?? {};
              final photoUrl = profile['photo_url'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(profile['display_name'] ?? 'Unknown'),
                subtitle: Text(profile['email'] ?? ''),
                trailing: Text('x${rsvp['attending_count']}'),
              );
            }),
          ],
        ],
      ),
    );
  }
}
