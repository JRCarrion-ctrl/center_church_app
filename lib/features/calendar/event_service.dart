// File: lib/features/calendar/event_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/group_event.dart';
import 'models/app_event.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch upcoming app-wide events added by supervisors.
  Future<List<AppEvent>> fetchAppEvents() async {
    try {
      final today = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(today.year, today.month, today.day);

      final data = await _supabase
          .from('app_events')
          .select()
          .gte('event_date', startOfDay.toIso8601String())
          .order('event_date', ascending: true);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map((json) => AppEvent.fromMap(json))
          .toList();
    } on PostgrestException catch (error) {
      if (error.message.contains('relation "public.app_events" does not exist')) {
        debugPrint('app_events table missing; returning empty list');
        return [];
      }
      throw Exception('Error loading app events: ${error.message}');
    }
  }

  /// Save (insert or update) an app-wide event.
  Future<void> saveAppEvent(AppEvent event) async {
    try {
      if (event.id.isEmpty) {
        final insertData = {
          'title': event.title,
          'description': event.description,
          'image_url': event.imageUrl,
          'event_date': event.eventDate.toIso8601String(),
        };
        await _supabase.from('app_events').insert(insertData);
      } else {
        final updateData = {
          'title': event.title,
          'body': event.description,
          'image_url': event.imageUrl,
          'event_date': event.eventDate.toIso8601String(),
        };
        await _supabase.from('app_events').update(updateData).eq('id', event.id);
      }
    } on PostgrestException catch (error) {
      throw Exception('Error saving app event: ${error.message}');
    }
  }

  /// Delete an app-wide event.
  Future<void> deleteAppEvent(String eventId) async {
    try {
      await _supabase.from('app_events').delete().eq('id', eventId);
    } on PostgrestException catch (error) {
      throw Exception('Error deleting app event: ${error.message}');
    }
  }

  /// Fetch upcoming group-specific events for all groups the user is a member of.
  Future<List<GroupEvent>> fetchUpcomingGroupEvents() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    List<String> groupIds;
    try {
      final membershipData = await _supabase
          .from('group_memberships')
          .select('group_id')
          .eq('user_id', userId)
          .eq('status', 'approved');
      groupIds = (membershipData as List)
          .map((row) => (row as Map<String, dynamic>)['group_id'] as String)
          .toList();
    } on PostgrestException catch (error) {
      throw Exception('Error loading memberships: ${error.message}');
    }
    if (groupIds.isEmpty) return [];

    try {
      final today = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(today.year, today.month, today.day);

      final data = await _supabase
          .from('group_events')
          .select()
          .inFilter('group_id', groupIds)
          .gte('event_date', startOfDay.toIso8601String())
          .order('event_date', ascending: true);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map((json) => GroupEvent.fromMap(json))
          .toList();
    } on PostgrestException catch (error) {
      throw Exception('Error loading group events: ${error.message}');
    }
  }

  /// Fetch upcoming events for a single group.
  Future<List<GroupEvent>> fetchGroupEvents(String groupId) async {
    try {
      final today = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(today.year, today.month, today.day);

      final data = await _supabase
          .from('group_events')
          .select()
          .eq('group_id', groupId)
          .gte('event_date', startOfDay.toIso8601String())
          .order('event_date', ascending: true);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map((json) => GroupEvent.fromMap(json))
          .toList();
    } on PostgrestException catch (error) {
      throw Exception('Error loading group events: ${error.message}');
    }
  }

  /// Fetch all events (past & future) for a single group.
  Future<List<GroupEvent>> fetchAllGroupEvents(String groupId) async {
    try {
      final data = await _supabase
          .from('group_events')
          .select()
          .eq('group_id', groupId)
          .order('event_date', ascending: false);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map((json) => GroupEvent.fromMap(json))
          .toList();
    } on PostgrestException catch (error) {
      throw Exception('Error loading all group events: ${error.message}');
    }
  }

  /// Fetch a single group event by ID.
  Future<GroupEvent?> getEventById(String eventId) async {
    try {
      final json = await _supabase
          .from('group_events')
          .select()
          .eq('id', eventId)
          .maybeSingle();
      if (json == null) return null;
      return GroupEvent.fromMap(json);
    } on PostgrestException catch (error) {
      throw Exception('Error loading event: ${error.message}');
    }
  }

  /// Save (insert or update) a group event.
  Future<void> saveEvent(GroupEvent event) async {
    final data = event.toMap();
    try {
      if (event.id.isEmpty) {
        data
          ..remove('id')
          ..removeWhere((k, v) => v == null);
        await _supabase.from('group_events').insert(data);
        return;
      }

      final updateData = event.toMap()..remove('id');
      await _supabase.from('group_events').update(updateData).eq('id', event.id);
    } on PostgrestException catch (error) {
      throw Exception('Error saving event: ${error.message}');
    }
  }

  /// Delete a group event.
  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase.from('group_events').delete().eq('id', eventId);
    } on PostgrestException catch (error) {
      throw Exception('Error deleting event: ${error.message}');
    }
  }

  /// Fetch all RSVPs for a given event, including profile info.
  Future<List<Map<String, dynamic>>> fetchRSVPS(String eventId) async {
    try {
      final data = await _supabase
          .from('event_attendance')
          .select('user_id, attending_count, profiles(display_name, email)')
          .eq('event_id', eventId);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (error) {
      throw Exception('Error loading RSVPS: ${error.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRSVPs(String eventId) async {
    try {
      final data = await _supabase
          .from('event_attendance')
          .select('attending_count, profiles(display_name, email)')
          .eq('event_id', eventId);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (error) {
      throw Exception('Error loading RSVPs: ${error.message}');
    }
  }

  /// RSVP to an app-wide event
  Future<void> rsvpAppEvent({required String appEventId, required int count}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _supabase.from('app_event_attendance').upsert({
      'app_event_id': appEventId,
      'user_id': userId,
      'attending_count': count,
    }, onConflict: 'app_event_id, user_id');
  }

  /// Fetch RSVPs for an app-wide event
  Future<List<Map<String, dynamic>>> fetchAppEventRSVPs(String appEventId) async {
    final data = await _supabase
        .from('app_event_attendance')
        .select('attending_count, profiles(display_name, email)')
        .eq('app_event_id', appEventId);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
