// File: lib/features/calendar/pages/group_event_details_page.dart
import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'package:ccf_app/routes/router_observer.dart';
import 'package:ccf_app/core/time_service.dart';
import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';

class GroupEventDetailsPage extends StatefulWidget {
  final GroupEvent event;
  const GroupEventDetailsPage({super.key, required this.event});

  @override
  State<GroupEventDetailsPage> createState() => _GroupEventDetailsPageState();
}

class _GroupEventDetailsPageState extends State<GroupEventDetailsPage> with RouteAware {
  late EventService _eventService; 
  int _attendingCount = 1;
  bool _saving = false;
  bool _isSupervisor = false;
  List<Map<String, dynamic>> _rsvps = [];
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    routeObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
    
    if (!_inited) {
      _inited = true;
      
      final client = GraphProvider.of(context);
      final userId = context.read<AppState>().profile?.id;
      _eventService = EventService(client, currentUserId: userId);

      _checkRole();
      _loadRSVPs();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadRSVPs();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null || uid.isEmpty) return;
    
    try {
      final role = await _eventService.checkGroupMemberRole(
        groupId: widget.event.groupId,
        userId: uid,
      );
      if (!mounted) return;
      setState(() {
        _isSupervisor = const {'leader', 'supervisor', 'owner', 'admin'}.contains(role);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSupervisor = false);
    }
  }

  Future<void> _removeRSVP() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null || uid.isEmpty) return;

    setState(() => _saving = true);

    try {
      await _eventService.removeGroupEventRSVP(widget.event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_136".tr())),
      );
      _loadRSVPs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')), 
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadRSVPs() async {
    try {
      final data = await _eventService.fetchGroupEventRSVPs(widget.event.id);
      if (!mounted) return;

      final currentUserId = context.read<AppState>().profile?.id;
      int currentAttendingCount = 1; // Default to 1 if no RSVP is found

      if (currentUserId != null) {
        try {
          // Use a try-catch block to safely find the existing RSVP
          final existingRsvp = data.firstWhere(
            (r) => r['user_id'] == currentUserId,
          );
          currentAttendingCount = existingRsvp['attending_count'] as int? ?? 1;
        } catch (e) {
          // StateError means no element was found, which is okay.
          // We just proceed with the default count of 1.
        }
      }

      setState(() {
        _rsvps = data;
        _attendingCount = currentAttendingCount;
      });
    } catch (e) {
      // Handle potential errors from the network request itself
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load RSVP data: $e")),
        );
      }
    }
  }

  // REFACTORED: Now uses the EventService for GraphQL logic
  Future<void> _submitRSVP() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in')),
      );
      return;
    }

    setState(() => _saving = true);

    // NOTE: This assumes EventService has an rsvpGroupEvent method
    try {
      await _eventService.rsvpGroupEvent(
        eventId: widget.event.id, 
        count: _attendingCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_138".tr())),
      );
      _loadRSVPs();
    } catch (e) {
      if (!mounted) return;
      // We rely on the service to provide an informative exception
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void addEventToCalendar(GroupEvent event) {
    final calendarEvent = Event(
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
    final currentUserId = context.watch<AppState>().profile?.id; // text id
    final hasRSVP = currentUserId != null && _rsvps.any((r) => r['user_id'] == currentUserId);
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
            label: Text("key_140".tr()),
          ),
          const Divider(height: 32),
          Text("key_140a".tr(), style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              Text("key_141".tr()),
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
                child: _saving ? const CircularProgressIndicator() : Text("key_142".tr()),
              ),
              if (hasRSVP)
                TextButton(
                  onPressed: _saving ? null : _removeRSVP,
                  child: Text("key_143".tr(), style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const Divider(height: 32),
          if (_isSupervisor && _rsvps.isNotEmpty) ...[
            Text("key_143a".tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._rsvps.map((rsvp) {
              // NOTE: If your fetchGroupEventRSVPs query uses 'profiles', 
              // the key below should be 'profiles', otherwise it should be 'profile'
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