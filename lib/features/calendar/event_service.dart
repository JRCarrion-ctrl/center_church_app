// File: lib/features/calendar/event_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/group_event.dart';

class EventService {
  final supabase = Supabase.instance.client;

  /// Fetch events from all groups the current user is a member of
  Future<List<GroupEvent>> fetchUpcomingEvents() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Step 1: Get group_ids the user is a member of
    final membershipData = await supabase
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'approved');

    final groupIds = (membershipData as List)
        .map((row) => row['group_id'] as String)
        .toSet();

    if (groupIds.isEmpty) return [];

    // Step 2: Fetch events from those groups, ordered by date
    final eventData = await supabase
        .from('group_events')
        .select()
        .inFilter('group_id', groupIds.toList())
        .gte('event_date', DateTime.now().toIso8601String()) // only future
        .order('event_date', ascending: true);

    return (eventData as List)
        .map((row) => GroupEvent.fromMap(row))
        .toList();
  }

  Future<List<GroupEvent>> fetchGroupEvents(String groupId) async {
    final response = await supabase
        .from('group_events')
        .select()
        .eq('group_id', groupId)
        .gte('event_date', DateTime.now().toIso8601String())
        .order('event_date', ascending: true);

    return (response as List)
        .map((e) => GroupEvent.fromMap(e))
        .toList();
  }

  /// Fetch a single event by ID
  Future<GroupEvent?> getEventById(String eventId) async {
    final response = await supabase
        .from('group_events')
        .select()
        .eq('id', eventId)
        .single();

    return GroupEvent.fromMap(response);
  }

  /// RSVP to an event (with attendee count)
  Future<void> rsvp({required String eventId, required int count}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Upsert so a user can RSVP again without duplicates
    await supabase.from('event_attendance').upsert({
      'event_id': eventId,
      'user_id': userId,
      'attending_count': count,
    }, onConflict: 'event_id, user_id');
  }

  /// Save (insert or update) a group event
  Future<void> saveEvent(GroupEvent event) async {
    final data = event.toMap();

    // Check if the event already exists
    final existing = await supabase
        .from('group_events')
        .select('id')
        .eq('id', event.id)
        .maybeSingle();

    if (existing != null) {
      await supabase
          .from('group_events')
          .update(data)
          .eq('id', event.id);
    } else {
      await supabase
          .from('group_events')
          .insert(data);
    }
  }

  /// Delete a group event
  Future<void> deleteEvent(String eventId) async {
    await supabase.from('group_events').delete().eq('id', eventId);
  }

  /// Fetch all RSVPs for a given event, including profile info
  Future<List<Map<String, dynamic>>> fetchRSVPs(String eventId) async {
    final response = await supabase
        .from('event_attendance')
        .select('attending_count, profiles(display_name, email)')
        .eq('event_id', eventId);

    return (response as List).cast<Map<String, dynamic>>();
  }
}
