// File: lib/features/calendar/church_event_service.dart
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'models/church_event.dart';

class _ChurchEventQueries {
  // ----------------------------------------
  // 1. FETCH QUERIES (The State Machine)
  // ----------------------------------------

  // Replaces: appEvents (Main Calendar)
  static const fetchPublicEvents = r'''
    query FetchPublicEvents($from: timestamptz!, $langs: [String!]!) {
      events(
        where: { 
          event_date: { _gte: $from },
          visibility: { _eq: "public_app" },
          status: { _in: ["approved", "pending_approval"] },
          target_audiences: { _contains: $langs }
        },
        order_by: { event_date: asc }
      ) {
        id title description image_url event_date event_end location 
        target_audiences rrule group_id visibility status
        group { name }
      }
    }
  ''';

  // Replaces: fetchMyUpcomingGroupEvents (User's Dashboard)
  static const fetchMyGroupEvents = r'''
    query FetchMyGroupEvents($uid: String!, $from: timestamptz!) {
      events(
        where: {
          event_date: { _gte: $from },
          status: { _in: ["approved", "pending_approval"] },
          visibility: { _eq: "group_only" },
          group: {
            group_memberships: {
              user_id: { _eq: $uid },
              status: { _eq: "approved" }
            }
          }
        },
        order_by: { event_date: asc }
      ) {
        id title description image_url event_date event_end location 
        target_audiences rrule group_id visibility status
        group { name }
      }
    }
  ''';

  // Replaces: fetchGroupEvents (Specific Group Page)
  static const fetchEventsForGroup = r'''
    query FetchEventsForGroup($groupId: uuid!, $from: timestamptz!) {
      events(
        where: {
          group_id: { _eq: $groupId }, 
          event_date: { _gte: $from },
          status: { _in: ["approved", "pending_approval"] } 
        }, 
        order_by: { event_date: asc }
      ) {
        id title description image_url event_date event_end location 
        target_audiences rrule group_id visibility status
        group { name }
        rsvps_aggregate { aggregate { sum { attending_count } } }
      }
    }
  ''';

  static const approveEvent = r'''
    mutation ApproveEvent($id: uuid!) {
      update_events_by_pk(
        pk_columns: {id: $id}, 
        _set: {status: "approved"}
      ) {
        id
        status
      }
    }
  ''';

  static const getEventById = r'''
    query GetEventByPk($id: uuid!) {
      events_by_pk(id: $id) {
        id title description image_url event_date event_end location 
        target_audiences rrule group_id visibility status
        group { name }
      }
    }
  ''';

  // ----------------------------------------
  // 2. MUTATIONS (Insert / Update / Delete)
  // ----------------------------------------

  static const insertEvent = r'''
    mutation InsertEvent($object: events_insert_input!) {
      insert_events_one(object: $object) { id }
    }
  ''';

  static const updateEvent = r'''
    mutation UpdateEvent($id: uuid!, $set: events_set_input!) {
      update_events_by_pk(pk_columns: {id: $id}, _set: $set) { id }
    }
  ''';

  static const deleteEvent = r'''
    mutation DeleteEvent($id: uuid!) {
      delete_events_by_pk(id: $id) { id }
    }
  ''';
  
  // ----------------------------------------
  // 3. SLOTS & ASSIGNMENTS (V2)
  // ----------------------------------------

  static const fetchEventSlots = r'''
    query FetchEventSlots($eventId: uuid!) {
      unified_event_slots(where: {event_id: {_eq: $eventId}}, order_by: {title: asc}) {
        id
        title
        max_slots
        # We use an alias here so it perfectly matches your ChurchEventSlot Dart model!
        slot_assignments_aggregate: unified_slot_assignments_aggregate {
          aggregate { sum { quantity } }
        }
      }
    }
  ''';

  static const upsertEventSlots = r'''
    mutation UpsertEventSlots($objects: [unified_event_slots_insert_input!]!) {
      insert_unified_event_slots(
        objects: $objects,
        on_conflict: {
          constraint: unified_event_slots_pkey,
          update_columns: [title, max_slots]
        }
      ) { affected_rows }
    }
  ''';

  static const deleteEventSlots = r'''
    mutation DeleteEventSlots($ids: [uuid!]!) {
      delete_unified_event_slots(where: {id: {_in: $ids}}) { affected_rows }
    }
  ''';

  static const claimSlot = r'''
    mutation ClaimSlot($slotId: uuid!, $userId: String!, $quantity: Int!) {
      insert_unified_slot_assignments_one(
        object: { slot_id: $slotId, user_id: $userId, quantity: $quantity }
        on_conflict: {
          constraint: unique_unified_slot_assignment,
          update_columns: [quantity]
        }
      ) { id }
    }
  ''';

  static const unclaimSlot = r'''
    mutation UnclaimSlot($slotId: uuid!, $userId: String!) {
      delete_unified_slot_assignments(where: { slot_id: {_eq: $slotId}, user_id: {_eq: $userId} }) {
        affected_rows
      }
    }
  ''';

  static const fetchUserAssignments = r'''
    query FetchUserAssignments($slotIds: [uuid!]!, $userId: String!) {
      unified_slot_assignments(where: { user_id: {_eq: $userId}, slot_id: {_in: $slotIds} }) {
        slot_id
        quantity
      }
    }
  ''';

  // ----------------------------------------
  // 4. RSVPS (V2)
  // ----------------------------------------

  static const upsertRSVP = r'''
    mutation UpsertRSVP($eventId: uuid!, $userId: String!, $count: Int!) {
      insert_unified_event_rsvps_one(
        object: { event_id: $eventId, user_id: $userId, attending_count: $count }
        on_conflict: {
          constraint: unique_unified_event_rsvp
          update_columns: [attending_count]
        }
      ) { id }
    }
  ''';

  static const removeRSVP = r'''
    mutation RemoveRSVP($eventId: uuid!, $userId: String!) {
      delete_unified_event_rsvps(where: { event_id: { _eq: $eventId }, user_id: { _eq: $userId } }) { 
        affected_rows 
      }
    }
  ''';

  static const fetchRSVPs = r'''
    query FetchEventRSVPs($eventId: uuid!) {
      unified_event_rsvps(where: {event_id: {_eq: $eventId}}) {
        user_id
        attending_count
        # Assuming you have a relationship to your users/profiles table setup in Hasura
        profile { 
          display_name
          email
          photo_url
        }
      }
    }
  ''';
}

class ChurchEventService {
  final GraphQLClient _gql;
  final String? _currentUserId;

  ChurchEventService(this._gql, {String? currentUserId}) : _currentUserId = currentUserId;

  DateTime get _startOfRecentHistory {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day).subtract(const Duration(days: 30));
  }

  // --- CORE FETCH HELPER ---
  Future<List<ChurchEvent>> _fetchEvents(String document, Map<String, dynamic> variables) async {
    try {
      final res = await _gql.query(QueryOptions(
        document: gql(document),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (res.hasException) throw res.exception!;
      
      final list = (res.data?['events'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ChurchEvent.fromMap)
          .toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching unified events: $e');
      rethrow;
    }
  }

  // --- PUBLIC API ---

  Future<List<ChurchEvent>> fetchPublicEvents(List<String> languages) async {
    return _fetchEvents(_ChurchEventQueries.fetchPublicEvents, {
      'from': _startOfRecentHistory.toIso8601String(),
      'langs': languages,
    });
  }

  Future<List<ChurchEvent>> fetchMyGroupEvents() async {
    if (_currentUserId == null) throw Exception('User not logged in');
    return _fetchEvents(_ChurchEventQueries.fetchMyGroupEvents, {
      'uid': _currentUserId,
      'from': _startOfRecentHistory.toIso8601String(),
    });
  }

  Future<List<ChurchEvent>> fetchEventsForGroup(String groupId) async {
    return _fetchEvents(_ChurchEventQueries.fetchEventsForGroup, {
      'groupId': groupId,
      'from': _startOfRecentHistory.toIso8601String(),
    });
  }

  Future<ChurchEvent?> getEventById(String eventId) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_ChurchEventQueries.getEventById), 
      variables: {'id': eventId}, 
      fetchPolicy: FetchPolicy.networkOnly
    ));
    if (res.hasException) throw res.exception!;
    final json = res.data?['events_by_pk'] as Map<String, dynamic>?;
    return json == null ? null : ChurchEvent.fromMap(json);
  }

  // --- ROLE CHECKS ---
  
  Future<bool> isUserAdminInGroup({required String groupId, required String userId}) async {
    const qRole = r'''
      query MyGroupRole($gid: uuid!, $uid: String!) {
        group_memberships(
          where: {
            group_id: { _eq: $gid },
            user_id: { _eq: $uid },
            status: { _eq: "approved" }
          }
          limit: 1
        ) { role }
      }
    ''';
    try {
      final res = await _gql.query(QueryOptions(
        document: gql(qRole),
        variables: {'gid': groupId, 'uid': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (res.hasException) return false;
      String? role;
      final rows = (res.data?['group_memberships'] as List?) ?? const [];
      if (rows.isNotEmpty) role = rows.first['role'] as String?;
      const adminRoles = {'admin', 'leader', 'supervisor', 'owner'};
      return adminRoles.contains(role);
    } catch (_) {
      return false;
    }
  }

  Future<String> checkGroupMemberRole({required String groupId, required String userId}) async {
    const qRole = r'''
      query MemberRole($gid: uuid!, $uid: String!) {
        group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
          limit: 1
        ) { role }
      }
    ''';
    final res = await _gql.query(QueryOptions(
      document: gql(qRole),
      fetchPolicy: FetchPolicy.noCache,
      variables: {'gid': groupId, 'uid': userId},
    ));
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_memberships'] as List?) ?? const [];
    return rows.isEmpty ? 'member' : (rows.first['role'] as String? ?? 'member');
  }

  // --- UNIFIED SAVE METHOD ---
  Future<void> saveEvent(ChurchEvent event, {List<ChurchEventSlot> slots = const []}) async {
    final isNew = event.id.isEmpty;
    String finalEventId = event.id;
    
    final Map<String, dynamic> eventData = {
      'title': event.title,
      'description': event.description,
      'image_url': event.imageUrl,
      'event_date': event.eventDate.toUtc().toIso8601String(),
      'event_end': event.eventEnd?.toUtc().toIso8601String(),
      'location': event.location,
      'target_audiences': event.targetAudiences,
      'rrule': event.rrule,
      'group_id': event.groupId,
      'visibility': event.visibility,
    };

    if (isNew) {
      // 1. INSERT MAIN EVENT (And slots at the same time if applicable)
      if (slots.isNotEmpty) {
        eventData['unified_event_slots'] = { 'data': slots.map((s) => s.toUpsertMap()).toList() };
      }
      final res = await _gql.mutate(MutationOptions(
        document: gql(_ChurchEventQueries.insertEvent),
        variables: {'object': eventData},
        fetchPolicy: FetchPolicy.noCache,
      ));
      if (res.hasException) throw Exception('Error inserting event: ${res.exception}');
      finalEventId = res.data?['insert_events_one']['id'];
      
    } else {
      // 2. UPDATE MAIN EVENT
      final res = await _gql.mutate(MutationOptions(
        document: gql(_ChurchEventQueries.updateEvent),
        variables: { 'id': event.id, 'set': eventData },
        fetchPolicy: FetchPolicy.noCache,
      ));
      if (res.hasException) throw Exception('Error updating event: ${res.exception}');
      
      // 3. SYNC SLOTS (If updating)
      final existingSlots = await fetchEventSlots(finalEventId);
      final dbIds = existingSlots.map((s) => s.id).whereType<String>().toSet();
      final uiIds = slots.map((s) => s.id).whereType<String>().toSet();
      
      final idsToDelete = dbIds.difference(uiIds).toList();
      if (idsToDelete.isNotEmpty) {
        await _gql.mutate(MutationOptions(
          document: gql(_ChurchEventQueries.deleteEventSlots),
          variables: {'ids': idsToDelete},
        ));
      }

      if (slots.isNotEmpty) {
        final slotsPayload = slots.map((s) {
          final map = s.toUpsertMap();
          map['event_id'] = finalEventId;
          if (s.id != null) map['id'] = s.id;
          return map;
        }).toList();
        
        await _gql.mutate(MutationOptions(
          document: gql(_ChurchEventQueries.upsertEventSlots),
          variables: {'objects': slotsPayload},
        ));
      }
    }
  }

  Future<void> approveEvent(String eventId) async {
    final res = await _gql.mutate(MutationOptions(
      document: gql(_ChurchEventQueries.approveEvent),
      variables: {'id': eventId},
      fetchPolicy: FetchPolicy.noCache,
    ));
    
    if (res.hasException) {
      throw Exception('Error approving event: ${res.exception}');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final res = await _gql.mutate(MutationOptions(
      document: gql(_ChurchEventQueries.deleteEvent), 
      variables: {'id': eventId}
    ));
    if (res.hasException) throw Exception('Error deleting event: ${res.exception}');
  }

  // --- SLOTS LOGIC ---
  
  Future<List<ChurchEventSlot>> fetchEventSlots(String eventId) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_ChurchEventQueries.fetchEventSlots),
      variables: {'eventId': eventId},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (res.hasException) throw res.exception!;
    return (res.data?['unified_event_slots'] as List? ?? [])
        .map((s) => ChurchEventSlot.fromMap(s))
        .toList();
  }

  Future<void> claimSlot({required String slotId, int quantity = 1}) async {
    if (_currentUserId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_ChurchEventQueries.claimSlot),
      variables: { 'slotId': slotId, 'userId': _currentUserId, 'quantity': quantity },
    ));
    if (res.hasException) throw Exception('Could not sign up for slot: ${res.exception}');
  }
  
  Future<void> unclaimSlot({required String slotId}) async {
    if (_currentUserId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_ChurchEventQueries.unclaimSlot),
      variables: { 'slotId': slotId, 'userId': _currentUserId },
    ));
    if (res.hasException) throw Exception('Could not remove slot: ${res.exception}');
  }

  Future<Map<String, int>> fetchUserAssignments(List<String> slotIds) async {
    if (_currentUserId == null || slotIds.isEmpty) return {};
    final res = await _gql.query(QueryOptions(
      document: gql(_ChurchEventQueries.fetchUserAssignments),
      variables: { 'slotIds': slotIds, 'userId': _currentUserId },
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (res.hasException) return {};

    final List data = res.data?['unified_slot_assignments'] ?? [];
    final Map<String, int> result = {};
    for (var row in data) {
      result[row['slot_id']] = row['quantity'] as int;
    }
    return result;
  }

  // --- RSVP LOGIC ---

  Future<void> rsvpEvent({required String eventId, required int count}) async {
    if (_currentUserId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_ChurchEventQueries.upsertRSVP),
      variables: {'eventId': eventId, 'userId': _currentUserId, 'count': count},
    ));
    if (res.hasException) throw Exception('Error saving RSVP: ${res.exception}');
  }

  Future<void> removeRSVP(String eventId) async {
    if (_currentUserId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_ChurchEventQueries.removeRSVP),
      variables: {'eventId': eventId, 'userId': _currentUserId},
    ));
    if (res.hasException) throw Exception('Error deleting RSVP: ${res.exception}');
  }

  Future<List<Map<String, dynamic>>> fetchEventRSVPs(String eventId) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_ChurchEventQueries.fetchRSVPs),
      variables: {'eventId': eventId},
      fetchPolicy: FetchPolicy.networkOnly
    ));
    if (res.hasException) throw res.exception!;
    return (res.data?['unified_event_rsvps'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }
}