// filename: app_event_details_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

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
        SnackBar(content: Text("key_please_log_in".tr())),
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
    
    // Check if current user has an RSVP entry in the fetched list
    final myRsvpEntry = currentUserId != null && _rsvps.isNotEmpty
        ? _rsvps.firstWhere(
            (r) => r['user_id'] == currentUserId, 
            orElse: () => {},
          )
        : <String, dynamic>{};
        
    final hasRSVP = myRsvpEntry.isNotEmpty;

    final userRole = context.select<AppState, UserRole?>((s) => s.userRole);
    final bool isSupervisor = userRole == UserRole.supervisor || userRole == UserRole.owner || userRole == UserRole.leader;

    // --- NEW LOGIC: Calculate "Others" count ---
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
        // If we can't pop (Deep Link), show a Close button that goes Home
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
          // ... Existing Image, Title, Date, Desc, Location widgets ...
          if (e.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: e.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox(
                  child: Center(child: CircularProgressIndicator())
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  child: Center(child: Icon(Icons.broken_image, size: 100))
                ),
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
          
          // RSVP INPUT SECTION
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

          // --- UPDATED RSVP LIST DISPLAY SECTION ---
          if (_rsvps.isNotEmpty) ...[
            Text("key_033b".tr(), style: Theme.of(context).textTheme.titleMedium), // "Who is going?"
            const SizedBox(height: 8),

            // 1. IF SUPERVISOR: Show Everyone
            if (isSupervisor)
              ..._rsvps.map((rsvp) => _buildRsvpTile(rsvp))

            // 2. IF REGULAR USER: Show Self + Count of others
            else ...[
              // A. Show "My RSVP" if it exists
              if (hasRSVP) 
                _buildRsvpTile(myRsvpEntry),

              // B. Show Count of others
              if (othersCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    // You might want to create a localization key like: 
                    // "key_others_count": "+ {} others are attending"
                    "+ $othersCount others are attending", 
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ]
          ]
        ],
      ),
    );
  }

  // Helper to keep the build method clean
  Widget _buildRsvpTile(Map<String, dynamic> rsvp) {
    final profile = rsvp['profile'] ?? {};
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

class AppEventDeepLinkWrapper extends StatefulWidget {
  final String eventId;
  final AppEvent? preloadedEvent;

  const AppEventDeepLinkWrapper({
    super.key,
    required this.eventId,
    this.preloadedEvent,
  });

  @override
  State<AppEventDeepLinkWrapper> createState() => _AppEventDeepLinkWrapperState();
}

class _AppEventDeepLinkWrapperState extends State<AppEventDeepLinkWrapper> {
  // Make this nullable so we can check if it has been initialized
  Future<AppEvent?>? _eventFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // We initialize the Future in didChangeDependencies to safely access the GraphQLProvider
    // inside the context.
    if (_eventFuture == null && widget.preloadedEvent == null) {
      _eventFuture = _fetchEvent(widget.eventId);
    }
  }

  Future<AppEvent?> _fetchEvent(String id) async {
    try {
      final client = GraphQLProvider.of(context).value;

      // Query to fetch a single event by PK
      const String query = r'''
        query GetAppEvent($id: uuid!) {
          app_events_by_pk(id: $id) {
            id
            title
            description
            event_date
            location
            image_url
          }
        }
      ''';

      final result = await client.query(QueryOptions(
        document: gql(query),
        variables: {'id': id},
        fetchPolicy: FetchPolicy.networkOnly, // Ensure fresh data
      ));

      if (result.hasException) {
        debugPrint('Deep Link Error: ${result.exception.toString()}');
        return null;
      }

      final data = result.data?['app_events_by_pk'];
      
      if (data == null) return null;

      // Manually map the result to AppEvent to avoid factory mismatch issues.
      // If you have a factory like AppEvent.fromJson(data), you can use that instead.
      return AppEvent(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        // Parse the UTC date string from Hasura
        eventDate: DateTime.parse(data['event_date']), 
        location: data['location'],
        imageUrl: data['image_url'],
      );
    } catch (e) {
      debugPrint('Error fetching deep link event: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Normal Navigation (We have the object)
    if (widget.preloadedEvent != null) {
      return AppEventDetailsPage(event: widget.preloadedEvent!);
    }

    // 2. Deep Link Navigation (We need to fetch it)
    return FutureBuilder<AppEvent?>(
      future: _eventFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return Scaffold(
             appBar: AppBar(), // Empty app bar for consistency
             body: const Center(child: CircularProgressIndicator()),
           );
        }

        if (snapshot.hasError || snapshot.data == null) {
           return Scaffold(
             appBar: AppBar(title: Text("key_error".tr())), // "Error"
             body: Center(
               child: Text("key_event_not_found".tr()), // "Event not found"
             ),
           );
        }

        // 3. Data Loaded -> Show the actual page
        return AppEventDetailsPage(event: snapshot.data!);
      },
    );
  }
}