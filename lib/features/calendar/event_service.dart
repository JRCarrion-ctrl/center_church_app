// File: lib/features/calendar/event_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/group_event.dart';
import 'models/app_event.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime get _startOfTodayUtc {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  // ----------------------
  // App-Wide Events
  // ----------------------

  Future<List<AppEvent>> fetchAppEvents() async {
    try {
      final data = await _supabase
          .from('app_events')
          .select()
          .gte('event_date', _startOfTodayUtc.toIso8601String())
          .order('event_date', ascending: true);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(AppEvent.fromMap)
          .toList();
    } on PostgrestException catch (error) {
      if (error.message.contains('relation "public.app_events" does not exist')) {
        debugPrint('app_events table missing; returning empty list');
        return [];
      }
      throw Exception('Error loading app events: ${error.message}');
    }
  }

  Future<void> saveAppEvent(AppEvent event) async {
    final isNew = event.id.isEmpty;
    final data = {
      'title': event.title,
      'description': event.description,
      'image_url': event.imageUrl,
      'event_date': event.eventDate.toUtc().toIso8601String(),
      'location': event.location,
    };

    try {
      if (isNew) {
        await _supabase.from('app_events').insert(data);
      } else {
        await _supabase.from('app_events').update(data).eq('id', event.id);
      }
    } on PostgrestException catch (error) {
      throw Exception('Error saving event: ${error.message}');
    }
  }

  Future<void> deleteAppEvent(String eventId) async {
    try {
      await _supabase.from('app_events').delete().eq('id', eventId);
    } on PostgrestException catch (error) {
      throw Exception('Error deleting event: ${error.message}');
    }
  }

  // ----------------------
  // Group Events
  // ----------------------

  Future<List<GroupEvent>> fetchUpcomingGroupEvents() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      final memberships = await _supabase
          .from('group_memberships')
          .select('group_id')
          .eq('user_id', userId)
          .eq('status', 'approved');

      final groupIds = (memberships as List)
          .map((row) => row['group_id'] as String)
          .toList();

      if (groupIds.isEmpty) return [];

      final data = await _supabase
          .from('group_events')
          .select()
          .inFilter('group_id', groupIds)
          .gte('event_date', _startOfTodayUtc.toIso8601String())
          .order('event_date', ascending: true);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(GroupEvent.fromMap)
          .toList();
    } on PostgrestException catch (error) {
      throw Exception('Error loading group events: ${error.message}');
    }
  }

  Future<List<GroupEvent>> fetchGroupEvents(String groupId) async {
    try {
      final data = await _supabase
          .from('group_events')
          .select()
          .eq('group_id', groupId)
          .gte('event_date', _startOfTodayUtc.toIso8601String())
          .order('event_date', ascending: true);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(GroupEvent.fromMap)
          .toList();
    } on PostgrestException catch (error) {
      throw Exception('Error loading group events: ${error.message}');
    }
  }

  Future<List<GroupEvent>> fetchAllGroupEvents(String groupId) async {
    try {
      final data = await _supabase
          .from('group_events')
          .select()
          .eq('group_id', groupId)
          .order('event_date', ascending: false);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(GroupEvent.fromMap)
          .toList();
    } on PostgrestException catch (error) {
      throw Exception('Error loading all group events: ${error.message}');
    }
  }

  Future<GroupEvent?> getEventById(String eventId) async {
    try {
      final json = await _supabase
          .from('group_events')
          .select()
          .eq('id', eventId)
          .maybeSingle();

      return json == null ? null : GroupEvent.fromMap(json);
    } on PostgrestException catch (error) {
      throw Exception('Error loading event: ${error.message}');
    }
  }

  Future<void> saveEvent(GroupEvent event) async {
    final data = event.toMap();
    try {
      if (event.id.isEmpty) {
        data
          ..remove('id')
          ..removeWhere((_, v) => v == null);
        await _supabase.from('group_events').insert(data);
      } else {
        final updateData = Map.of(data)..remove('id');
        await _supabase.from('group_events').update(updateData).eq('id', event.id);
      }
    } on PostgrestException catch (error) {
      throw Exception('Error saving event: ${error.message}');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase.from('group_events').delete().eq('id', eventId);
    } on PostgrestException catch (error) {
      throw Exception('Error deleting event: ${error.message}');
    }
  }

  // ----------------------
  // RSVP Methods
  // ----------------------

  Future<List<Map<String, dynamic>>> fetchGroupEventRSVPs(String eventId) async {
    try {
      final data = await _supabase
          .from('event_attendance')
          .select('user_id, attending_count, profiles(display_name, email)')
          .eq('event_id', eventId);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (error) {
      throw Exception('Error loading RSVPs: ${error.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroupEventRSVPsLite(String eventId) async {
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

  Future<void> rsvpAppEvent({required String appEventId, required int count}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await _supabase.from('app_event_attendance').upsert({
      'app_event_id': appEventId,
      'user_id': userId,
      'attending_count': count,
    }, onConflict: 'app_event_id, user_id');
  }

  Future<List<Map<String, dynamic>>> fetchAppEventRSVPs(String appEventId) async {
    try {
      final data = await _supabase
          .from('app_event_attendance')
          .select('user_id, attending_count, profiles(display_name, email)')
          .eq('app_event_id', appEventId);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (error) {
      throw Exception('Error loading app RSVPs: ${error.message}');
    }
  }

  Future<void> removeAppEventRSVP(String appEventId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not authenticated");

    await _supabase
        .from('app_event_attendance')
        .delete()
        .eq('app_event_id', appEventId)
        .eq('user_id', userId);
  }
}
