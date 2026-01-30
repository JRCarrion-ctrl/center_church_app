// File: lib/features/calendar/pages/group_event_details_page.dart
import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_app/routes/router_observer.dart';
import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../../calendar/event_service.dart';
import '../../calendar/models/group_event.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

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
      int currentAttendingCount = 1; 

      if (currentUserId != null) {
        try {
          final existingRsvp = data.firstWhere(
            (r) => r['user_id'] == currentUserId,
          );
          currentAttendingCount = existingRsvp['attending_count'] as int? ?? 1;
        } catch (e) {
          // No RSVP found for current user
        }
      }

      setState(() {
        _rsvps = data;
        _attendingCount = currentAttendingCount;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load RSVP data: $e")),
        );
      }
    }
  }

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
      // --- UPDATED: Use actual end time ---
      endDate: event.eventEnd ?? event.eventDate.add(const Duration(hours: 1)),
      location: event.location ?? '5115 Pegasus Ct. Frederick, MD 21704 United States',
    );
    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  // --- NEW: Helper to format "Start - End" time nicely ---
  String _formatEventTime(DateTime startUtc, DateTime? endUtc) {
    final start = startUtc.toLocal();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(start);
    final startStr = DateFormat('h:mm a').format(start);
    
    if (endUtc != null) {
      final end = endUtc.toLocal();
      // If same day, just show time range: "Friday... 5:00 PM - 7:00 PM"
      if (DateUtils.isSameDay(start, end)) {
        final endStr = DateFormat('h:mm a').format(end);
        return '$dateStr • $startStr - $endStr';
      } else {
        // If different day, show full end date
         final endDateStr = DateFormat('MMM d, h:mm a').format(end);
         return '$dateStr • $startStr - $endDateStr';
      }
    }
    
    return '$dateStr • $startStr';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AppState>().profile?.id; 
    
    final myRsvpEntry = currentUserId != null && _rsvps.isNotEmpty
        ? _rsvps.firstWhere((r) => r['user_id'] == currentUserId, orElse: () => {})
        : <String, dynamic>{};

    final hasRSVP = myRsvpEntry.isNotEmpty;
    final e = widget.event;

    int othersCount = 0;
    for (var rsvp in _rsvps) {
      if (rsvp['user_id'] != currentUserId) {
        othersCount += (rsvp['attending_count'] as int? ?? 0);
      }
    }

    final canPop = GoRouter.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: Text(e.title),
        leading: canPop
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/'),
              ),
      ),
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
          
          // --- UPDATED: Use the new format helper ---
          Text(
            _formatEventTime(e.eventDate, e.eventEnd),
            style: Theme.of(context).textTheme.bodyMedium, // Use explicit style for consistency
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
          
          if (_rsvps.isNotEmpty) ...[
            Text("key_143a".tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            if (_isSupervisor)
               ..._rsvps.map((rsvp) => _buildRsvpTile(rsvp))

            else ...[
              if (hasRSVP)
                _buildRsvpTile(myRsvpEntry),
              
              if (othersCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    "+ $othersCount others are attending",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ]
          ],
        ],
      ),
    );
  }

  Widget _buildRsvpTile(Map<String, dynamic> rsvp) {
    final profile = rsvp['profiles'] ?? {}; 
    final photoUrl = profile['photo_url'];
    final displayName = profile['display_name'] ?? 'Unknown';
    final email = profile['email'] ?? '';
    final count = rsvp['attending_count'];

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(displayName),
      subtitle: Text(email),
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer
          ),
        ),
      ),
    );
  }
}

class GroupEventDeepLinkWrapper extends StatefulWidget {
  final String eventId;
  final GroupEvent? preloadedEvent;

  const GroupEventDeepLinkWrapper({
    super.key,
    required this.eventId,
    this.preloadedEvent,
  });

  @override
  State<GroupEventDeepLinkWrapper> createState() => _GroupEventDeepLinkWrapperState();
}

class _GroupEventDeepLinkWrapperState extends State<GroupEventDeepLinkWrapper> {
  Future<GroupEvent?>? _eventFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (_eventFuture == null && widget.preloadedEvent == null) {
      _eventFuture = _fetchEventById(widget.eventId);
    }
  }

  Future<GroupEvent?> _fetchEventById(String id) async {
    try {
      final client = GraphProvider.of(context); 

      // --- UPDATED: Fetch event_end ---
      const String query = r'''
        query GetGroupEvent($id: uuid!) {
          group_events_by_pk(id: $id) {
            id
            group_id
            title
            description
            event_date
            event_end
            location
            image_url
            created_at
          }
        }
      ''';

      final result = await client.query(QueryOptions(
        document: gql(query),
        variables: {'id': id},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (result.hasException) {
        debugPrint('Group Event Deep Link Error: ${result.exception.toString()}');
        return null;
      }

      final data = result.data?['group_events_by_pk'];
      if (data == null) return null;

      return GroupEvent(
        id: data['id'],
        groupId: data['group_id'],
        title: data['title'],
        description: data['description'],
        eventDate: DateTime.parse(data['event_date']),
        // --- UPDATED: Parse event_end ---
        eventEnd: data['event_end'] != null ? DateTime.parse(data['event_end']) : null,
        location: data['location'],
        imageUrl: data['image_url'],
      );
    } catch (e) {
      debugPrint('Error fetching deep link group event: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preloadedEvent != null) {
      return GroupEventDetailsPage(event: widget.preloadedEvent!);
    }

    return FutureBuilder<GroupEvent?>(
      future: _eventFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(), 
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text("key_error".tr())),
            body: Center(child: Text("key_event_not_found".tr())),
          );
        }

        return GroupEventDetailsPage(event: snapshot.data!);
      },
    );
  }
}